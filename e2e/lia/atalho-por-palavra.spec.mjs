/*
 * Atalho por palavra: digitar só uma palavra-chave traz a resposta pronta inteira.
 *
 * Ponto de partida: a tela de login do Chatwoot e, depois dela, a lista de conversas
 *   (não a conversa).
 * Dados: o seed.rb cadastra na conta "Loja E2E 4" as respostas prontas
 *   "Documentação solicitar rede social" ("Você tem rede social, {{contact.name}}? Se
 *   puder, manda o link ou @ do seu perfil.") e "Você prefere um plano mais flexível".
 * Ação: a Bruna Atendente abre a conversa da Paula, digita "rede social", aceita com Tab
 *   e envia.
 * Resultado esperado exato:
 *   1. aparece a linha [data-test-id=lia-compose-hint] com o atalho
 *      [data-test-id=lia-compose-shortcut] = "Documentação solicitar rede social";
 *   2. depois do Tab o editor contém "Você tem rede social, Paula Souza? Se puder, manda
 *      o link ou @ do seu perfil." (a resposta inteira no lugar do que foi digitado, com
 *      o nome da cliente);
 *   3. a mensagem enviada aparece na conversa;
 *   4. a LIA grava 1 linha em reply_compose_events com outcome "accepted", source
 *      "canned_keyword", typed_chars 11 e agent_id = id da Bruna no Chatwoot.
 * Restauração do estado: o run.sh cria Chatwoot, LIA, bancos e Redis descartáveis e apaga
 *   tudo ao sair (trap EXIT), mesmo com falha. Nada toca produção nem homologação.
 * Como rodar (da raiz do chatwoot-locfit, com as dependências em e2e/lia: npm ci):
 *   Verde, com a imagem desta mudança:
 *   CHATWOOT_IMAGE=chatwoot-locfit:<commit> LIA_DIR=../LIA-camada2 \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh atalho-por-palavra
 *   Vermelho esperado na imagem de produção sem a mudança (a linha do atalho não aparece):
 *   CHATWOOT_IMAGE=developerlocfit/chatwoot-locfit:9d10b7d LIA_DIR=../LIA-camada2 \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh atalho-por-palavra
 * Evidência: e2e/lia/artifacts/<imagem>-<data>/ (trace.zip, screenshots, logs da LIA e
 *   do Chatwoot, playwright.log).
 */
import { execFileSync } from 'node:child_process';
import { test, expect } from '@playwright/test';

const SEED = JSON.parse(process.env.E2E_SEED || '{}').atalho || {};
const PG = process.env.LIA_PG_CONTAINER || 'lia-e2e-lia-pg';

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
      `SELECT outcome, source, typed_chars, agent_id FROM reply_compose_events WHERE agent_id = ${SEED.user_id}`,
    ],
    { encoding: 'utf8' }
  )
    .trim()
    .split('\n')
    .filter(Boolean);

test('palavra-chave traz a resposta pronta inteira', async ({ page }, info) => {
  const shot = name =>
    page.screenshot({ path: info.outputPath(`${name}.png`), fullPage: true });
  const typed = 'rede social';
  const full =
    'Você tem rede social, Paula Souza? Se puder, manda o link ou @ do seu perfil.';

  await page.goto('/app/login');
  await page.getByTestId('email_input').fill('bruna@e2e.test');
  await page.getByTestId('password_input').fill('Senha-e2e-123!');
  await page.getByTestId('submit_button').click();
  await page.waitForURL(/\/app\/accounts\/\d+\//);
  await shot('01-lista');

  await page.getByText('Paula Souza').first().click();
  const bubbles = page.locator('[id^="message"]');
  await expect(bubbles.getByText('Quanto custa?')).toBeVisible();

  const editor = page.locator('.ProseMirror').first();
  await editor.click();
  await page.keyboard.type(typed, { delay: 30 });

  const hint = page.locator('[data-test-id="lia-compose-hint"]');
  await expect(hint).toBeVisible({ timeout: 15_000 });
  await expect(
    page.locator('[data-test-id="lia-compose-shortcut"]')
  ).toHaveText('Documentação solicitar rede social');
  await shot('02-atalho');

  await page.keyboard.press('Tab');
  await expect(editor).toHaveText(full);
  await shot('03-completado');

  await page.getByRole('button', { name: /^Enviar/ }).click();
  await expect(editor).toHaveText('');
  await expect(bubbles.getByText(full)).toBeVisible();
  await shot('04-enviado');

  await expect.poll(composeEvents, { timeout: 15_000 }).toHaveLength(1);
  const [outcome, source, typedChars, agentId] = composeEvents()[0].split('|');
  expect({
    outcome,
    source,
    typedChars: Number(typedChars),
    agentId: Number(agentId),
  }).toEqual({
    outcome: 'accepted',
    source: 'canned_keyword',
    typedChars: typed.length,
    agentId: SEED.user_id,
  });
});
