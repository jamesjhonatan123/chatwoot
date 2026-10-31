/*
 * Autocompletar da LIA: a apresentação de atendente sai com o nome de quem digita.
 *
 * Ponto de partida: a tela de login do Chatwoot e, depois dela, a lista de conversas
 *   (não a conversa).
 * Dados: o run.sh grava no histórico da LIA três apresentações de outras atendentes
 *   ("Bom dia Ana, tudo bem? Aqui é a Brenda, vou continuar seu atendimento hoje.", a
 *   mesma para o Lucas, e "Aqui é o Fernando" para o Rui), cada uma numa conversa, e
 *   nenhuma resposta rápida com esse texto.
 * Ação: a Marina Atendente (conta própria, a "Loja E2E 2") abre a conversa da Paula, digita "<cumprimento da hora> Paula,
 *   tudo bem? Aqui é a" (bom dia/boa tarde/boa noite de Brasília), aceita com Tab e envia.
 * Resultado esperado exato:
 *   1. aparece, apagado no cursor, [data-test-id=lia-compose-ghost] com
 *      " Marina, vou continuar seu atendimento hoje." (o nome dela, não Brenda nem Fernando);
 *   2. depois do Tab o editor contém
 *      "<cumprimento> Paula, tudo bem? Aqui é a Marina, vou continuar seu atendimento hoje.";
 *   3. a mensagem enviada aparece na conversa;
 *   4. a LIA grava 1 linha em reply_compose_events com outcome "accepted",
 *      source "history" e agent_id = id da Marina no Chatwoot.
 * Restauração do estado: o run.sh cria Chatwoot, LIA, bancos e Redis descartáveis e apaga
 *   tudo ao sair (trap EXIT), mesmo com falha. Nada toca produção nem homologação.
 * Como rodar (da raiz do chatwoot-locfit, com as dependências em e2e/lia: npm ci):
 *   Verde, com a LIA que fabrica a apresentação:
 *   CHATWOOT_IMAGE=developerlocfit/chatwoot-locfit:latest LIA_DIR=../LIA-camada2 \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh autocompletar-apresentacao
 *   Vermelho esperado com a LIA de antes (main): LIA_DIR apontando para ela.
 * Evidência: e2e/lia/artifacts/<imagem>-<data>/ (trace.zip, screenshots, logs da LIA e
 *   do Chatwoot, playwright.log).
 */
import { execFileSync } from 'node:child_process';
import { test, expect } from '@playwright/test';

const SEED = JSON.parse(process.env.E2E_SEED || '{}').apresentacao || {};
const PG = process.env.LIA_PG_CONTAINER || 'lia-e2e-lia-pg';

// O cumprimento que a LIA põe no texto: o da hora de Brasília agora.
const greeting = () => {
  const hour = Number(
    new Intl.DateTimeFormat('en-US', {
      hour: 'numeric',
      hourCycle: 'h23',
      timeZone: 'America/Sao_Paulo',
    }).format(new Date())
  );
  if (hour < 12) return 'Bom dia';
  return hour < 18 ? 'Boa tarde' : 'Boa noite';
};

const composeEvents = () =>
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
      `SELECT outcome, source, agent_id FROM reply_compose_events WHERE agent_id = ${SEED.user_id}`,
    ],
    { encoding: 'utf8' }
  )
    .trim()
    .split('\n')
    .filter(Boolean);

test('apresentação de outra atendente completa com o nome de quem digita', async ({
  page,
}, info) => {
  const shot = name =>
    page.screenshot({ path: info.outputPath(`${name}.png`), fullPage: true });
  const typed = `${greeting()} Paula, tudo bem? Aqui é a`;
  const rest = ' Marina, vou continuar seu atendimento hoje.';

  await page.goto('/app/login');
  await page.getByTestId('email_input').fill('marina@e2e.test');
  await page.getByTestId('password_input').fill('Senha-e2e-123!');
  await page.getByTestId('submit_button').click();
  await page.waitForURL(/\/app\/accounts\/\d+\//);
  await shot('01-lista');

  // Só observa a resposta real do repertório, para o log da evidência.
  const library = page
    .waitForResponse(r => r.url().includes('/lia_suggestion/compose_library'), {
      timeout: 15_000,
    })
    .then(r => r.json())
    .catch(() => null);
  await page.getByText('Paula Souza').first().click();
  const libraryBody = await library;
  console.log(
    'compose_library:',
    libraryBody
      ? `${libraryBody.reason} ${JSON.stringify(libraryBody.texts?.map(t => t.text))}`
      : 'sem resposta'
  );
  const bubbles = page.locator('[id^="message"]');
  await expect(bubbles.getByText('Quanto custa?')).toBeVisible();

  const editor = page.locator('.ProseMirror').first();
  await editor.click();
  await page.keyboard.type(typed, { delay: 30 });

  const ghost = editor.locator('[data-test-id="lia-compose-ghost"]');
  await expect(ghost).toBeVisible({ timeout: 15_000 });
  await expect(ghost).toHaveText(rest);
  await shot('02-sugestao');

  await page.keyboard.press('Tab');
  await expect(ghost).toBeHidden();
  await expect(editor).toHaveText(typed + rest);
  await shot('03-completado');

  await page.getByRole('button', { name: /^Enviar/ }).click();
  await expect(editor).toHaveText('');
  await expect(bubbles.getByText(typed + rest)).toBeVisible();
  await shot('04-enviado');

  await expect.poll(composeEvents, { timeout: 15_000 }).toHaveLength(1);
  const [outcome, source, agentId] = composeEvents()[0].split('|');
  expect({ outcome, source, agentId: Number(agentId) }).toEqual({
    outcome: 'accepted',
    source: 'history',
    agentId: SEED.user_id,
  });
});
