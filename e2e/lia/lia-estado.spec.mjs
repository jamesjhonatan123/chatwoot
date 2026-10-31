/*
 * Selo da LIA na conversa: a atendente vê se a LIA responde na loja e liga/desliga dali.
 *
 * Por quê: em 31/10/2026 uma atendente desligou a LIA no painel, o botão de volta estava
 *   escondido e a rede passou o sábado sem resposta. O atalho fica onde ela trabalha.
 * Ponto de partida: a tela de login do Chatwoot e, depois dela, a lista de conversas
 *   (não a conversa).
 * Dados: o run.sh vincula, na LIA, a caixa da "Loja E2E 4" à loja 777
 *   (system_settings.chatwoot_inboxes). Banco da LIA novo: sem grade, sem exceção.
 * Ação: a Rita Atendente abre a conversa da Paula, clica no selo, desliga a LIA,
 *   confere o motivo, e liga de novo.
 * Resultado esperado exato:
 *   1. ao abrir a conversa, [data-test-id=lia-status-chip] diz "LIA respondendo";
 *   2. no painel do selo, o botão é "Desligar a LIA nesta loja (volta sozinha)" e
 *      aparece "Vale para todas as conversas desta loja.";
 *   3. depois de desligar, o selo diz "LIA em silêncio até <hora>" e o motivo
 *      [data-test-id=lia-status-label] começa com "Em silêncio até" e termina com
 *      "desligada por Rita Atendente";
 *   4. a LIA gravou __store__:777:human_support_override com mode "lia_off", um "until"
 *      e by "Rita Atendente"; nenhuma chave global human_support_* foi escrita
 *      (o clique numa conversa nunca muda a rede inteira);
 *   5. o botão vira "Ligar a LIA agora nesta loja"; clicar volta o selo a "LIA respondendo"
 *      e a exceção da loja 777 fica vazia ("{}").
 * Restauração do estado: o run.sh cria Chatwoot, LIA, bancos e Redis descartáveis e apaga
 *   tudo ao sair (trap EXIT), mesmo com falha. Nada toca produção nem homologação.
 * Como rodar (da raiz do chatwoot-locfit, com as dependências em e2e/lia: npm ci):
 *   Verde, com a imagem e a LIA desta mudança:
 *   CHATWOOT_IMAGE=chatwoot-locfit:<commit> LIA_DIR=../LIA-estado \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh lia-estado
 *   Vermelho esperado no Chatwoot sem a mudança (o selo não existe):
 *   CHATWOOT_IMAGE=chatwoot-locfit:67a68b7c2 LIA_DIR=../LIA-estado ... run.sh lia-estado
 *   Vermelho esperado na LIA sem a mudança (sem /api/lia-status: o selo fica só "LIA"):
 *   CHATWOOT_IMAGE=chatwoot-locfit:<commit> LIA_DIR=../LIA-2.0 ... run.sh lia-estado
 * Evidência: e2e/lia/artifacts/<imagem>-<data>/ (trace.zip, screenshots, logs da LIA e
 *   do Chatwoot, playwright.log).
 */
import { execFileSync } from 'node:child_process';
import { test, expect } from '@playwright/test';

const SEED = JSON.parse(process.env.E2E_SEED || '{}').estado || {};
const PG = process.env.LIA_PG_CONTAINER || 'lia-e2e-lia-pg';

const settings = like =>
  execFileSync(
    'docker',
    [
      'exec',
      PG,
      'psql',
      '-At',
      '-F',
      '|',
      '-U',
      'lia',
      '-d',
      'lia_e2e',
      '-c',
      `SELECT key, value FROM system_settings WHERE key LIKE '${like}' ORDER BY key`,
    ],
    { encoding: 'utf8' }
  )
    .trim()
    .split('\n')
    .filter(Boolean)
    .map(line => {
      const [key, ...rest] = line.split('|');
      return { key, value: rest.join('|') };
    });

test('atendente desliga e religa a LIA da loja pelo selo da conversa', async ({
  page,
}, info) => {
  const shot = name =>
    page.screenshot({ path: info.outputPath(`${name}.png`), fullPage: true });

  await page.goto('/app/login');
  await page.getByTestId('email_input').fill('rita@e2e.test');
  await page.getByTestId('password_input').fill('Senha-e2e-123!');
  await page.getByTestId('submit_button').click();
  await page.waitForURL(/\/app\/accounts\/\d+\//);
  await shot('01-lista');

  await page.getByText('Paula Souza').first().click();
  await expect(
    page.locator('[id^="message"]').getByText('Quanto custa?')
  ).toBeVisible();

  const chip = page.locator('[data-test-id="lia-status-chip"]');
  await expect(chip).toHaveText('LIA respondendo', { timeout: 15_000 });
  await shot('02-respondendo');

  await chip.click();
  const panel = page.locator('[data-test-id="lia-status-panel"]');
  const toggle = panel.locator('[data-test-id="lia-status-toggle"]');
  await expect(panel).toContainText('Vale para todas as conversas desta loja.');
  await expect(toggle).toHaveText('Desligar a LIA nesta loja (volta sozinha)');

  await toggle.click();
  await expect(chip).toHaveText(/LIA em silêncio até \S.*\d{2}:\d{2}/);
  const label = panel.locator('[data-test-id="lia-status-label"]');
  await expect(label).toHaveText(
    /Em silêncio até .+desligada por Rita Atendente\s*$/
  );
  await expect(toggle).toHaveText('Ligar a LIA agora nesta loja');
  await shot('03-desligada');
  console.log('selo:', await chip.innerText(), '| motivo:', await label.innerText());

  const [loja] = settings('__store__:777:human_support_override');
  const override = JSON.parse(loja.value);
  expect(override).toMatchObject({ mode: 'lia_off', by: 'Rita Atendente' });
  expect(override.until).toBeTruthy();
  expect(settings('human_support%')).toEqual([]);
  expect(settings('lia_enabled%')).toEqual([]);

  await toggle.click();
  await expect(chip).toHaveText('LIA respondendo');
  await expect(toggle).toHaveText('Desligar a LIA nesta loja (volta sozinha)');
  await shot('04-religada');
  expect(settings('__store__:777:human_support_override')).toEqual([
    { key: '__store__:777:human_support_override', value: '{}' },
  ]);
});
