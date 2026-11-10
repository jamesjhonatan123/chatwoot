/*
 * A faixa da LIA acompanha a mensagem que acabou de chegar, com a conversa aberta.
 *
 * Defeito (produção, 03 a 09/11/2026): o painel pede a sugestão 0,8 s depois de a
 * mensagem aparecer, mas a LIA só a grava 2 s depois. A resposta era a sugestão da
 * mensagem ANTERIOR (ou nada), e o painel não perguntava de novo: de 277 faixas
 * exibidas, só 23 apareceram em até 6 s da mensagem.
 *
 * Ponto de partida: a tela de login do Chatwoot e, depois dela, a lista de conversas.
 *   Na LIA, a conversa da Paula está em atendimento humano e a pergunta antiga dela
 *   ("Oi, quero alugar uma bike. Quanto custa?") tem a sugestão "Sugestão da pergunta
 *   antiga: …" pendente.
 * Ação: a Sofia abre a conversa da Paula e a faixa mostra a sugestão antiga. Com a
 *   conversa aberta, a Paula manda "Pode ser na quarta-feira de manhã?" (mensagem criada
 *   pela API do Chatwoot; em seguida o webhook dela chega à LIA, na mesma ordem da
 *   produção). Ninguém troca de conversa nem recarrega a página.
 * Resultado esperado exato:
 *   1. em até 20 s a faixa deixa de mostrar "Sugestão da pergunta antiga";
 *   2. no lugar aparece "Sem sugestão segura para esta mensagem." (a LIA não tem resposta
 *      pronta para a pergunta nova; o que importa é a faixa ser a da mensagem nova);
 *   3. o painel recebeu ao menos uma resposta com reason "waiting" antes da definitiva;
 *   4. na LIA a mensagem nova está gravada com o id que ela tem no Chatwoot.
 *   Na imagem anterior a faixa continua com a sugestão antiga (falha no passo 1).
 * Restauração do estado: o run.sh cria Chatwoot, LIA, bancos e Redis descartáveis e apaga
 *   tudo ao sair (trap EXIT), mesmo com falha. Nada toca produção nem homologação.
 * Como rodar (da raiz do chatwoot-locfit, com as dependências em e2e/lia: npm ci):
 *   CHATWOOT_IMAGE=<imagem com a mudança> LIA_DIR=<LIA com a mudança> \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh faixa-na-hora.spec.mjs
 *   Vermelho esperado na imagem sem a mudança:
 *   CHATWOOT_IMAGE=developerlocfit/chatwoot-locfit:latest LIA_DIR=<LIA com a mudança> \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh faixa-na-hora.spec.mjs
 * Evidência: e2e/lia/artifacts/<imagem>-<data>/ (trace.zip, screenshots, logs).
 */
import { test, expect } from '@playwright/test';
import { SEED, entrar, liaSql, prova } from './apoio.mjs';

const FAIXA = SEED.faixa || {};
const LIA_URL = process.env.LIA_URL;
const ANTIGA = 'Sugestão da pergunta antiga';
const NOVA = 'Pode ser na quarta-feira de manhã?';
const SEM_SUGESTAO = 'Sem sugestão segura para esta mensagem.';

test.afterEach(async ({ page }) => {
  await prova(page, 'faixa-mensagem-nova');
});

test('a faixa troca para a mensagem nova sem sair da conversa', async ({
  page,
  request,
}) => {
  await entrar(page, 'sofia@e2e.test');
  await page.getByText('Paula Souza').first().click();
  const faixa = page.getByRole('region', { name: 'Sugestão pronta' });
  await expect(faixa).toContainText(ANTIGA, { timeout: 20_000 });

  const motivos = [];
  page.on('response', async response => {
    if (!/\/lia_suggestion(\?|$)/.test(response.url())) return;
    const body = await response.json().catch(() => null);
    if (body) motivos.push(body.reason);
  });

  // A cliente manda a mensagem nova: primeiro ela existe no Chatwoot (e aparece na
  // tela), depois o webhook dela chega à LIA, como na produção.
  const criada = await request.post(
    `/api/v1/accounts/${FAIXA.account_id}/conversations/${FAIXA.conversation_id}/messages`,
    {
      headers: { api_access_token: FAIXA.api_token },
      data: { content: NOVA, message_type: 'incoming' },
    }
  );
  expect(criada.ok()).toBeTruthy();
  const mensagem = await criada.json();
  const webhook = await request.post(`${LIA_URL}/webhook/e2e`, {
    data: {
      event: 'message_created',
      id: mensagem.id,
      content: NOVA,
      message_type: 'incoming',
      private: false,
      account: { id: FAIXA.account_id },
      inbox: { id: FAIXA.inbox_id },
      conversation: {
        id: FAIXA.conversation_id,
        account_id: FAIXA.account_id,
        inbox_id: FAIXA.inbox_id,
        meta: { sender: { phone_number: '+5511999990005' } },
      },
      sender: {
        id: 1,
        type: 'contact',
        name: 'Paula Souza',
        phone_number: '+5511999990005',
      },
    },
  });
  expect(webhook.ok()).toBeTruthy();
  await expect(page.locator('[id^="message"]').getByText(NOVA)).toBeVisible();

  await expect(page.getByText(ANTIGA)).toBeHidden({ timeout: 20_000 });
  await expect(page.getByText(SEM_SUGESTAO)).toBeVisible({ timeout: 20_000 });
  expect(motivos).toContain('waiting');
  expect(
    liaSql(
      `SELECT count(*) FROM conversation_messages WHERE message_id = '${mensagem.id}' AND role = 'user'`
    )
  ).toEqual(['1']);
});
