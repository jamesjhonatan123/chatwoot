/*
 * Autocompletar escrito pela LIA: continua o que a atendente começou a digitar quando o
 * repertório não tem um texto que comece igual.
 *
 * Ponto de partida: a tela de login do Chatwoot e, depois dela, a lista de conversas.
 *   Na LIA, a conversa da Paula é da loja 778, que tem o autocompletar escrito pela LIA
 *   ligado (`reply_compose_generative`) e a resposta rápida "Todo o processo de locação é
 *   feito pelo nosso site: você escolhe o equipamento e o plano, cadastra o endereço de
 *   entrega e paga com cartão de crédito." Para a LIA, a última fala da Paula é "Como
 *   funciona a locação?" (no Chatwoot a conversa mostra a mensagem do seed).
 * Ação: a Helena abre a conversa e digita "Funciona assim: todo o processo de locação é"
 *   (não é o começo de nenhum texto do repertório, então o autocompletar de antes não
 *   tem o que mostrar), espera a continuação, aceita com Tab e envia pelo botão "Enviar".
 * Resultado esperado exato:
 *   1. dentro do editor aparece, apagado no cursor, [data-test-id=lia-compose-ghost] com
 *      "feito pelo nosso site", e abaixo a linha [data-test-id=lia-compose-hint] com
 *      "Tab", "para completar" e "escrito pela LIA";
 *   2. depois do Tab o texto apagado some e o editor começa pelo que ela digitou e
 *      contém "feito pelo nosso site";
 *   3. a mensagem enviada aparece na conversa;
 *   4. a LIA grava 1 linha em reply_compose_events com source "lia", outcome "accepted"
 *      e agent_id = id da Helena no Chatwoot.
 *   Na imagem anterior o texto apagado nunca aparece (falha no passo 1).
 * Restauração do estado: o run.sh cria Chatwoot, LIA, bancos e Redis descartáveis e apaga
 *   tudo ao sair (trap EXIT), mesmo com falha. Nada toca produção nem homologação.
 * Como rodar (da raiz do chatwoot-locfit, com as dependências em e2e/lia: npm ci):
 *   CHATWOOT_IMAGE=<imagem com a mudança> LIA_DIR=<LIA com a mudança> \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh autocompletar-lia.spec.mjs
 *   Vermelho esperado na imagem sem a mudança:
 *   CHATWOOT_IMAGE=developerlocfit/chatwoot-locfit:latest LIA_DIR=<LIA com a mudança> \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh autocompletar-lia.spec.mjs
 * Evidência: e2e/lia/artifacts/<imagem>-<data>/ (trace.zip, screenshots, logs).
 */
import { test, expect } from '@playwright/test';
import { SEED, entrar, liaSql, prova } from './apoio.mjs';

const COPILOTO = SEED.copiloto || {};
const DIGITADO = 'Funciona assim: todo o processo de locação é';
const CONTINUA = /feito pelo nosso site/i;

const usos = () =>
  liaSql(
    `SELECT outcome, source, agent_id FROM reply_compose_events WHERE agent_id = ${COPILOTO.user_id}`
  );

// Na falha (imagem anterior) o print de prova é o da tela sem o texto apagado; quando
// passa, o print é tirado no meio do teste, com o texto apagado à vista.
test.afterEach(async ({ page }, info) => {
  if (info.status !== info.expectedStatus)
    await prova(page, 'autocompletar-lia');
});

test('a LIA continua a frase, o Tab aceita e o uso é gravado', async ({
  page,
}) => {
  await entrar(page, 'helena@e2e.test');
  await page.getByText('Paula Souza').first().click();
  await expect(
    page.locator('[id^="message"]').getByText('Quanto custa?')
  ).toBeVisible();

  const editor = page.locator('.ProseMirror').first();
  await editor.click();
  await page.keyboard.type(DIGITADO, { delay: 30 });

  const ghost = editor.locator('[data-test-id="lia-compose-ghost"]');
  const hint = page.locator('[data-test-id="lia-compose-hint"]');
  await expect(ghost).toBeVisible({ timeout: 20_000 });
  await expect(ghost).toHaveText(CONTINUA);
  await expect(hint).toContainText('Tab');
  await expect(hint).toContainText('para completar');
  await expect(hint).toContainText('escrito pela LIA');
  await prova(page, 'autocompletar-lia');

  await page.keyboard.press('Tab');
  await expect(ghost).toBeHidden();
  await expect(editor).toContainText(DIGITADO);
  await expect(editor).toHaveText(CONTINUA);

  await page.getByRole('button', { name: /^Enviar/ }).click();
  await expect(editor).toHaveText('');
  await expect(
    page.locator('[id^="message"]').getByText(CONTINUA)
  ).toBeVisible();

  await expect.poll(usos, { timeout: 15_000 }).toHaveLength(1);
  const [outcome, source, agentId] = usos()[0].split('|');
  expect({ outcome, source, agentId: Number(agentId) }).toEqual({
    outcome: 'accepted',
    source: 'lia',
    agentId: COPILOTO.user_id,
  });
});
