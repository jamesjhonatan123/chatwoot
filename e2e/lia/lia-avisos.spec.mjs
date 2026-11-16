/*
 * A equipe vê, sem abrir conversa por conversa, quando a LIA está parada e quem espera.
 *
 * Defeito (15 e 16/11/2026): a LIA ficou desligada numa loja das 13h10 à meia-noite e
 *   cinco clientes transferidos pela LIA ficaram sem resposta. O estado da LIA só
 *   aparecia dentro de cada conversa, nada juntava quem esperava, e a passagem feita
 *   pela LIA não deixava marca nenhuma no Chatwoot.
 * Ponto de partida: a tela de login do Chatwoot e, depois dela, a lista de conversas.
 * Dados (seed.rb, conta "Loja E2E 8", caixa vinculada na LIA à loja 888 "Loja Avisos"):
 *   Paula Souza escreveu há 74 min, Marcos Lima há 20 min ("Vocês entregam em Joinville?")
 *   e Ana Costa há 5 min; ninguém respondeu. A LIA está respondendo na loja.
 * Ação e resultado esperado exato:
 *   1. com a LIA respondendo, não há faixa (role alert/status "LIA parada"); o menu tem o
 *      link "Esperando a equipe" com o contador 2 e o título da aba começa com "(2) ";
 *   2. a fila lista Paula e depois Marcos (Ana, com 5 min, fica fora), Paula "há 1h 1x"
 *      em vermelho e os dois com o motivo "Sem resposta";
 *   3. a atendente desliga a LIA pelo selo da conversa da Ana; na hora aparece a faixa
 *      (role alert) "LIA parada em Loja Avisos · Em silêncio até … desligada por Lia
 *      Teixeira Atendente. · 2 clientes esperando, o mais antigo há 1h 1x.";
 *   4. "Ver quem espera" abre a fila, e Marcos agora tem o motivo "LIA parada nesta loja";
 *   5. "Ligar a LIA agora" na faixa religa: a faixa some e a exceção da loja 888 na LIA
 *      fica "{}";
 *   6. a passagem da LIA (team_handoff.announce, o código do turno) na conversa do Marcos
 *      deixa a nota privada "🔒 LIA transferiu para a equipe" com o motivo, a etiqueta
 *      lia-transferiu (cadastrada na conta e na conversa), a prioridade "high", e na fila
 *      o motivo dele vira "LIA transferiu".
 *   Na imagem de produção sem a mudança falha no passo 1 (não existe o link da fila).
 * Restauração do estado: o run.sh cria Chatwoot, LIA, bancos e Redis descartáveis e apaga
 *   tudo ao sair (trap EXIT), mesmo com falha. Nada toca produção nem homologação.
 * Como rodar (da raiz do chatwoot-locfit, com as dependências em e2e/lia: npm ci):
 *   CHATWOOT_IMAGE=chatwoot-locfit:<commit> LIA_DIR=<LIA-2.0 com a mudança> \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh lia-avisos.spec.mjs
 *   Vermelho esperado: CHATWOOT_IMAGE=developerlocfit/chatwoot-locfit:latest (produção).
 * Evidência: e2e/lia/artifacts/<imagem>-<data>/ (trace.zip, screenshots, logs).
 */
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test, expect } from '@playwright/test';
import { SEED, entrar, liaSql, prova } from './apoio.mjs';

const AVISOS = SEED.avisos || {};
const ESPERA = AVISOS.esperando || {};
const AQUI = path.dirname(fileURLToPath(import.meta.url));

const override = () =>
  liaSql(
    "SELECT value FROM system_settings WHERE key = '__store__:888:human_support_override'"
  );

const passagemDaLia = conversationId =>
  JSON.parse(
    execFileSync(
      process.env.LIA_PYTHON,
      [
        path.join(AQUI, 'lia-passagem.py'),
        process.env.CHATWOOT_URL,
        AVISOS.token,
        String(AVISOS.account_id),
        String(conversationId),
      ],
      {
        encoding: 'utf8',
        cwd: AQUI,
        env: {
          PATH: process.env.PATH,
          HOME: process.env.HOME,
          PYTHONPATH: process.env.LIA_DIR,
          DATABASE_URL: 'postgresql+asyncpg://x:y@127.0.0.1:1/z',
        },
      }
    )
      .trim()
      .split('\n')
      .pop()
  );

const chatwootApi = async (request, url) => {
  const resposta = await request.get(url, {
    headers: { api_access_token: AVISOS.token },
  });
  expect(resposta.ok()).toBeTruthy();
  return resposta.json();
};

test('faixa da LIA parada, fila de quem espera e passagem visível', async ({
  page,
  request,
}, info) => {
  const shot = name =>
    page.screenshot({ path: info.outputPath(`${name}.png`), fullPage: true });
  const conta = `/app/accounts/${AVISOS.account_id}`;
  const faixa = page.getByRole('alert').filter({ hasText: 'LIA parada' });
  const fila = page.getByRole('link', { name: /Esperando a equipe/ });
  const linha = nome => page.getByRole('link', { name: new RegExp(nome) });

  await entrar(page, 'teixeira@e2e.test');

  // 1. LIA respondendo: sem faixa; contador no menu e no título.
  await expect(fila).toContainText('2', { timeout: 20_000 });
  await expect(faixa).toHaveCount(0);
  await expect(page).toHaveTitle(/^\(2\) /);
  await expect(page.getByText('Paula Souza').first()).toBeVisible();
  await prova(page, 'conversas');
  await shot('01-sem-faixa');

  // 2. A fila: o mais antigo em cima, quem tem 5 min fica fora.
  await fila.click();
  await expect(
    page.getByRole('heading', { name: /Esperando a equipe/ })
  ).toBeVisible();
  const linhas = page
    .getByRole('list', { name: 'Esperando a equipe' })
    .getByRole('link');
  await expect(linhas).toHaveCount(2);
  await expect(linhas.nth(0)).toContainText('Paula Souza');
  await expect(linhas.nth(0)).toContainText(/há 1h 1\d/);
  await expect(linhas.nth(1)).toContainText('Marcos Lima');
  await expect(linhas.nth(1)).toContainText('Vocês entregam em Joinville?');
  await expect(linhas.nth(1)).toContainText('Sem resposta');
  await expect(linha('Ana Costa')).toHaveCount(0);
  await prova(page, 'fila');
  await shot('02-fila');

  // 3. Desliga pelo selo da conversa da Ana: a faixa aparece na hora.
  await page.goto(`${conta}/conversations/${ESPERA['Ana Costa']}`);
  const chip = page.locator('[data-test-id="lia-status-chip"]');
  await expect(chip).toHaveText('LIA respondendo', { timeout: 15_000 });
  await chip.click();
  await page
    .getByRole('button', { name: 'Desligar a LIA nesta loja (volta sozinha)' })
    .click();
  await expect(chip).toHaveText(/LIA em silêncio/);
  await expect(faixa).toBeVisible({ timeout: 10_000 });
  await expect(faixa).toContainText('LIA parada em Loja Avisos');
  await expect(faixa).toContainText('desligada por Lia Teixeira Atendente');
  await expect(faixa).toContainText(
    /2 clientes esperando, o mais antigo há 1h 1\d\./
  );
  console.log('faixa:', await faixa.innerText());
  await prova(page, 'faixa');
  await shot('03-faixa');

  // 4. "Ver quem espera": o Marcos agora espera porque a LIA está parada.
  await faixa.getByRole('link', { name: 'Ver quem espera' }).click();
  await expect(linha('Marcos Lima')).toContainText('LIA parada nesta loja');
  await shot('04-fila-lia-parada');

  // 5. Religa pela faixa.
  await faixa.getByRole('button', { name: 'Ligar a LIA agora' }).click();
  await expect(faixa).toHaveCount(0, { timeout: 10_000 });
  expect(override()).toEqual(['{}']);
  await shot('05-religada');

  // 6. A passagem da LIA na conversa do Marcos.
  const resultado = passagemDaLia(ESPERA['Marcos Lima']);
  expect(resultado).toEqual({
    nota: true,
    etiqueta_na_conta: true,
    etiqueta: true,
    prioridade: true,
  });
  const base = `/api/v1/accounts/${AVISOS.account_id}`;
  const conversa = await chatwootApi(
    request,
    `${base}/conversations/${ESPERA['Marcos Lima']}`
  );
  expect(conversa.priority).toBe('high');
  expect(conversa.labels).toEqual(['lia-transferiu']);
  const etiquetas = await chatwootApi(request, `${base}/labels`);
  expect(etiquetas.payload.map(l => l.title)).toContain('lia-transferiu');

  await page.reload();
  await expect(linha('Marcos Lima')).toContainText('LIA transferiu', {
    timeout: 15_000,
  });
  await shot('06-fila-transferida');

  await linha('Marcos Lima').click();
  const nota = page
    .locator('[id^="message"]')
    .filter({ hasText: 'LIA transferiu para a equipe' });
  await expect(nota).toBeVisible();
  await expect(nota).toContainText(
    'Motivo: Cliente quer saber da entrega em Joinville'
  );
  await expect(nota).toContainText('O cliente leu da LIA');
  await prova(page, 'transferencia');
  await shot('07-nota-da-passagem');
});
