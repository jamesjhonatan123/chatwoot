/**
 * E2E: faixa "Sugestão pronta" da LIA dentro do campo de resposta do Chatwoot.
 *
 * SEM SIMULAÇÃO: Chatwoot (fork) e LIA reais rodando na máquina, Gemini real escolhendo
 * a resposta. Nada sai para WhatsApp/produção: a caixa é de canal API, a Evolution da LIA
 * aponta para uma porta morta e este teste NUNCA clica em Enviar nem aperta Enter no editor.
 * Não existe dump de homologação para estes dados: as fixtures são semeadas direto
 * (seed.rb no Chatwoot, seed-lia.sql na LIA).
 *
 * PONTO DE PARTIDA: lista de conversas do Chatwoot (/app/accounts/3/dashboard), já
 * logado como o atendente "e2e@example.com". NÃO é a conversa de destino.
 *
 * AÇÃO: abrir a conversa da "Ana Souza" (cliente perguntou "Qual o prazo de entrega da
 * bike depois que eu assino?") e, no campo de resposta:
 *   a) digitar "/" e apertar Tab (menu de respostas prontas aberto);
 *   b) alternar para "Mensagem Privada" e voltar para "Responder";
 *   c) com o editor vazio e focado, apertar Tab;
 *   d) recarregar a página e clicar no "×" da faixa.
 *
 * RESULTADO ESPERADO (exato):
 *   - faixa "Sugestão pronta · da resposta pronta" com o texto
 *     "Oi Ana! A entrega sai em até dois dias úteis depois da assinatura confirmada."
 *     (a resposta pronta /prazo, escolhida pelo Gemini real; {{contact.first_name}} já resolvido);
 *   - a) Tab com o menu "/" aberto NÃO insere a sugestão (o Tab é do menu);
 *   - b) em Mensagem Privada a faixa some; ao voltar para Responder ela volta;
 *   - c) o editor passa a ter exatamente o texto da sugestão e a faixa some;
 *   - d) após recarregar, o "×" some com a faixa e a linha em reply_suggestions da LIA
 *        fica com outcome = 'discarded';
 *   - nenhuma mensagem de saída nova no Chatwoot e nenhuma fala [HUMANO] na LIA.
 *
 * RESTAURAÇÃO: o teste apaga reply_suggestions da LIA no início (cada rodada gera uma
 * sugestão nova com o Gemini) e limpa o editor ao fim de cada passo. As fixtures
 * (conversa, mensagens, respostas prontas) não são alteradas.
 *
 * COMO RODAR:
 *   1. Postgres (pgvector/pgvector:pg16, nome cwe2e-pg, porta 5544) e Redis em docker; Chatwoot
 *      em docker ruby:3.4.4 na porta 3100 com LIA_API_URL=http://host.docker.internal:8000 e
 *      LIA_ADMIN_API_TOKEN=<valor descartável>, front compilado com `vite build --mode development`;
 *      `rails runner seed.rb` (este diretório) cria conta, atendente, caixa API, Ana e as respostas prontas.
 *   2. LIA local (branch agent/sugestao-chatwoot) em :8000 com DATABASE_URL do mesmo Postgres,
 *      CHATWOOT_* apontando para o Chatwoot local, EVOLUTION_API_URL morta, GOOGLE_API_KEY real
 *      e ADMIN_API_TOKEN igual ao do Chatwoot; `psql -d lia -f seed-lia.sql` semeia a conversa.
 *   3. cd <este diretório> && npx playwright test -c playwright.config.ts
 *   variáveis: CW_URL (padrão http://localhost:3100), CW_ACCOUNT, CW_CONVERSATION, E2E_OUT (traces/screenshots).
 *
 * ESPERADO POR VERSÃO:
 *   feature/updates       (produção, sem a faixa) -> VERMELHO (faixa nunca aparece)
 *   feature/lia-sugestao  (com a faixa)           -> VERDE
 */
import { test, expect, Page } from '@playwright/test';
import { execSync } from 'node:child_process';

const SUGGESTION = 'Oi Ana! A entrega sai em até dois dias úteis depois da assinatura confirmada.';
const ACCOUNT = process.env.CW_ACCOUNT || '3';
const CONVERSATION = process.env.CW_CONVERSATION || '1';
const EMAIL = 'e2e@example.com';
const PASSWORD = 'E2e-Pass!2026';

const psql = (db: string, sql: string) =>
  execSync(`docker exec -i cwe2e-pg psql -U postgres -d ${db} -At -c "${sql.replace(/"/g, '\\"')}"`)
    .toString()
    .trim();
const lia = (sql: string) => psql('lia', sql);
const chatwoot = (sql: string) => psql('chatwoot_e2e', sql);

const outgoingCount = () =>
  Number(chatwoot(`select count(*) from messages where message_type = 1 and conversation_id = (select id from conversations where display_id = ${CONVERSATION} and account_id = ${ACCOUNT})`));
const humanCount = () => Number(lia(`select count(*) from conversation_messages where content like '%[HUMANO]%'`));

const band = (page: Page) => page.getByRole('region', { name: 'Sugestão pronta' });
const editor = (page: Page) => page.locator('.reply-box .ProseMirror[contenteditable="true"]').first();
const editorText = async (page: Page) => ((await editor(page).innerText()) || '').trim();

async function clearEditor(page: Page) {
  await editor(page).click();
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.press('Backspace');
  await expect.poll(() => editorText(page)).toBe('');
  // o Chatwoot grava rascunho com atraso; espera ele registrar o editor vazio
  await page.waitForTimeout(2500);
}

test('faixa Sugestão pronta no campo de resposta (Gemini real)', async ({ page }, info) => {
  const out = info.outputDir;
  const shot = (name: string) => page.screenshot({ path: `${out}/${name}.png`, fullPage: false });

  const outgoingBefore = outgoingCount();
  const humanBefore = humanCount();
  lia('delete from reply_suggestions');

  // 0. login e ponto de partida: LISTA de conversas
  await page.goto('/app/login');
  await page.getByPlaceholder('example@companyname.com').fill(EMAIL);
  await page.getByPlaceholder('Password').fill(PASSWORD);
  await page.getByRole('button', { name: 'Login' }).click();
  await page.waitForURL(/\/app\/accounts\/\d+\/dashboard/);
  await page.goto(`/app/accounts/${ACCOUNT}/dashboard`);
  await expect(page).not.toHaveURL(/conversations\//);

  // 1. abrir a conversa da Ana pela lista
  await page.getByRole('listitem').filter({ hasText: /^Todos\s*\d*$/ }).first().click();
  await page.getByText('Ana Souza').first().click();
  await expect(page).toHaveURL(new RegExp(`/conversations/${CONVERSATION}`));
  await expect(page.getByText('Qual o prazo de entrega da bike depois que eu assino?').first()).toBeVisible();
  await shot('01-conversa-aberta');

  // 2. a faixa aparece com a resposta pronta escolhida pelo Gemini real
  await expect(band(page)).toBeVisible({ timeout: 60_000 });
  await expect(band(page)).toContainText('Sugestão pronta');
  await expect(band(page)).toContainText('da resposta pronta');
  await expect(band(page)).toContainText(SUGGESTION);
  await shot('02-faixa-visivel');

  // 4. (antes de usar a sugestão, para a faixa ainda estar viva) "/" abre o menu e o Tab é dele
  await editor(page).click();
  await page.keyboard.type('/');
  await expect(page.getByText('/horario')).toBeVisible();
  await shot('03-menu-barra-aberto');
  await page.keyboard.press('Tab');
  expect(await editorText(page)).not.toContain(SUGGESTION);
  // o Tab foi do menu: a seleção avançou para /horario (painel de pré-visualização)
  await expect(page.getByText('Nosso horário de atendimento é de segunda a sexta, das 9h às 18h.').last()).toBeVisible();
  await shot('04-apos-tab-no-menu');
  await page.keyboard.press('Escape');
  await clearEditor(page);
  await expect(band(page)).toBeVisible();

  // 5. Mensagem Privada esconde a faixa; voltar a mostra
  await page.getByText(/Mensagem Privada|Nota privada/i).first().click();
  await expect(band(page)).toBeHidden();
  await shot('05-nota-privada-sem-faixa');
  await page.getByText(/^Responder$/).first().click();
  await expect(band(page)).toBeVisible();

  // 3. Tab com editor vazio e focado insere exatamente a sugestão
  await editor(page).click();
  await page.keyboard.press('Tab');
  await expect.poll(() => editorText(page)).toBe(SUGGESTION);
  await expect(band(page)).toBeHidden();
  await shot('06-tab-inseriu-sugestao');
  await clearEditor(page);

  // 6. recarregar, descartar com o ×
  await page.reload();
  await expect(band(page)).toBeVisible({ timeout: 60_000 });
  await band(page).getByRole('button', { name: 'Descartar sugestão' }).click();
  await expect(band(page)).toBeHidden();
  await shot('07-descartada');
  await expect.poll(() => lia(`select outcome from reply_suggestions order by created_at desc limit 1`)).toBe('discarded');

  // 7. nada saiu
  expect(outgoingCount()).toBe(outgoingBefore);
  expect(humanCount()).toBe(humanBefore);
});
