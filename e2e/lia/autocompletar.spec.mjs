/*
 * Autocompletar da LIA na caixa de resposta do Chatwoot.
 *
 * Ponto de partida: a tela de login do Chatwoot e, depois dela, a lista de conversas
 *   (não a conversa nem o relatório).
 * Ação: a atendente abre a conversa da Paula, digita "Temos planos de aluguel a partir
 *   de R$189" (valor colado, sem o espaço que a resposta rápida tem depois do "R$"),
 *   aceita a sugestão com Tab e envia pelo botão "Enviar".
 * Resultado esperado exato:
 *   1. dentro do editor aparece, apagado no cursor, [data-test-id=lia-compose-ghost]
 *      com o restante da resposta rápida (",90 por mês, com entrega…"), e abaixo dele
 *      a linha [data-test-id=lia-compose-hint] "Tab para completar";
 *   2. depois do Tab o texto apagado some e o editor contém o que ela digitou seguido
 *      do restante ("…R$189,90 por mês, com entrega…");
 *   3. a mensagem enviada aparece na conversa;
 *   4. a LIA grava 1 linha em reply_compose_events com outcome "accepted",
 *      source "quick_reply" e agent_id = id da atendente no Chatwoot;
 *   5. em Relatórios > Sugestões da LIA, os cards mostram "Mensagens com a LIA" 100%,
 *      "Mensagens da equipe" 1 e "Autocompletar usado" 1, e a linha da "Carla Atendente"
 *      em "Uso da LIA por atendente" mostra 1 | 0 | 1 | 100%.
 * Restauração do estado: o run.sh cria Chatwoot, LIA, bancos e Redis descartáveis e apaga
 *   tudo ao sair (trap EXIT), mesmo com falha. Nada toca produção nem homologação.
 * Como rodar (da raiz do chatwoot-locfit, com as dependências em e2e/lia: npm ci):
 *   CHATWOOT_IMAGE=chatwoot-locfit:autocompletar LIA_DIR=../LIA-2.0-falha \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh
 *   Vermelho esperado na imagem sem a mudança:
 *   CHATWOOT_IMAGE=developerlocfit/chatwoot-locfit:latest LIA_DIR=../LIA-2.0-falha \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh
 * Evidência: e2e/lia/artifacts/<imagem>-<data>/ (trace.zip, screenshots, logs da LIA e
 *   do Chatwoot, playwright.log).
 */
import { execFileSync } from 'node:child_process';
import { test, expect } from '@playwright/test';

const SEED = JSON.parse(process.env.E2E_SEED || '{}');
const PG = process.env.LIA_PG_CONTAINER || 'lia-e2e-lia-pg';
const QUICK_REPLY =
  'Temos planos de aluguel a partir de R$ 189,90 por mês, com entrega e manutenção inclusas. Quer que eu te mande as opções?';
const TYPED = 'Temos planos de aluguel a partir de R$189';
// O que ela digitou fica como está; o autocompletar só acrescenta o restante.
const COMPLETED = QUICK_REPLY.replace('R$ 189', 'R$189');

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
      `SELECT outcome, source, agent_id, typed_chars FROM reply_compose_events WHERE agent_id = ${SEED.user_id}`,
    ],
    { encoding: 'utf8' }
  )
    .trim()
    .split('\n')
    .filter(Boolean);

test('Tab completa a resposta rápida, o uso é gravado e aparece no relatório', async ({
  page,
}, info) => {
  const shot = name =>
    page.screenshot({ path: info.outputPath(`${name}.png`), fullPage: true });

  await page.goto('/app/login');
  await page.getByTestId('email_input').fill('carla@e2e.test');
  await page.getByTestId('password_input').fill('Senha-e2e-123!');
  await page.getByTestId('submit_button').click();
  await page.waitForURL(/\/app\/accounts\/\d+\//);
  await shot('01-lista');

  // Só observa (não altera) a resposta real do repertório, para o log da evidência.
  // Na imagem sem o autocompletar a rota não existe: o teste segue e falha no que a
  // atendente vê (a sugestão não aparece), não aqui.
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
      ? `${libraryBody.reason} ${libraryBody.texts?.length ?? 0} textos`
      : 'sem resposta'
  );
  const bubbles = page.locator('[id^="message"]');
  await expect(bubbles.getByText('Quanto custa?')).toBeVisible();

  const editor = page.locator('.ProseMirror').first();
  await editor.click();
  await page.keyboard.type(TYPED, { delay: 30 });

  const ghost = editor.locator('[data-test-id="lia-compose-ghost"]');
  const hint = page.locator('[data-test-id="lia-compose-hint"]');
  await expect(ghost).toBeVisible({ timeout: 15_000 });
  await expect(ghost).toHaveText(
    ',90 por mês, com entrega e manutenção inclusas. Quer que eu te mande as opções?'
  );
  await expect(hint).toContainText('Tab');
  await expect(hint).toContainText('para completar');
  await shot('02-sugestao');

  await page.keyboard.press('Tab');
  await expect(ghost).toBeHidden();
  await expect(editor).toHaveText(COMPLETED);
  await expect(hint).toBeHidden();
  await shot('03-completado');

  await page.getByRole('button', { name: /^Enviar/ }).click();
  await expect(editor).toHaveText('');
  await expect(bubbles.getByText(COMPLETED)).toBeVisible();
  await shot('04-enviado');

  await expect.poll(composeEvents, { timeout: 15_000 }).toHaveLength(1);
  const [outcome, source, agentId, typedChars] = composeEvents()[0].split('|');
  expect({ outcome, source, agentId: Number(agentId) }).toEqual({
    outcome: 'accepted',
    source: 'quick_reply',
    agentId: SEED.user_id,
  });
  expect(Number(typedChars)).toBeGreaterThanOrEqual(12);

  await page.goto(`/app/accounts/${SEED.account_id}/reports/lia-sugestoes`);
  // Valor de um card: o <p> logo depois do rótulo (a tabela repete os rótulos em <th>).
  const card = label => page.locator(`p:text-is("${label}") + p`);
  await expect(card('Autocompletar usado')).toHaveText('1');
  await expect(card('Mensagens da equipe')).toHaveText('1');
  await expect(card('Mensagens com a LIA')).toHaveText('100%');
  const row = page
    .locator('[data-test-id="lia-usage-by-agent"] tbody tr')
    .filter({ hasText: 'Carla Atendente' });
  await expect(row.locator('td')).toHaveText([
    'Carla Atendente',
    '1',
    '0',
    '1',
    '100%',
  ]);
  await shot('05-relatorio');
});
