/*
 * Fila "Esperando a equipe" só com quem espera há até 7 dias.
 *
 * Pedido do dono (19/11/2026), com o print da fila de produção (208 conversas, de 141 a 172
 *   dias): "Muita mensagem aqui, não era pra estar assim ou é muito antiga. Dê uma olhada."
 *   As abandonadas, abertas e sem resposta há meses, escondiam quem escreveu hoje.
 * Ponto de partida: a tela de login do Chatwoot e, depois dela, a lista de conversas.
 * Dados (seed.rb, conta "Loja E2E 9"): Marcos Lima espera há 40 min; Rita Antiga escreveu
 *   há 150 dias e a conversa segue aberta.
 * Ação e resultado esperado exato:
 *   1. clicar em "Esperando a equipe" no menu: a fila tem 1 conversa, a do Marcos, sem a
 *      Rita, e o texto "1 conversa aberta e sem resposta há mais de 7 dias ficou fora da fila.";
 *   2. clicar em "Painel": o bloco "Esperando a equipe agora" lista só o Marcos e mostra o
 *      mesmo texto das abandonadas.
 *   Na imagem de produção sem a mudança falha no passo 1 (a fila tem 2: Rita e Marcos).
 * Restauração do estado: o run.sh cria Chatwoot, LIA, bancos e Redis descartáveis e apaga
 *   tudo ao sair (trap EXIT), mesmo com falha. Nada toca produção nem homologação.
 * Como rodar (da raiz do chatwoot-locfit, com as dependências em e2e/lia: npm ci):
 *   CHATWOOT_IMAGE=chatwoot-locfit:<commit> LIA_DIR=<LIA-2.0> \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh lia-fila-recente.spec.mjs
 *   Vermelho esperado: CHATWOOT_IMAGE=developerlocfit/chatwoot-locfit:latest (produção).
 */
import { test, expect } from '@playwright/test';
import { entrar, prova } from './apoio.mjs';

const ABANDONADAS =
  '1 conversa aberta e sem resposta há mais de 7 dias ficou fora da fila.';

test('a fila deixa de fora a conversa abandonada há 150 dias e só a conta', async ({
  page,
}) => {
  await entrar(page, 'vera@e2e.test');

  // 1. A fila "Esperando a equipe".
  await page.getByRole('link', { name: /Esperando a equipe/ }).click();
  await expect(
    page.getByRole('heading', { name: /Esperando a equipe/, level: 1 })
  ).toBeVisible();
  const linhas = page
    .getByRole('list', { name: 'Esperando a equipe' })
    .getByRole('link');
  await expect(linhas.first()).toBeVisible();
  await prova(page, 'fila');
  // Soft: na versão sem a mudança o teste segue até o Painel, para o print do "antes".
  await expect.soft(linhas).toHaveCount(1);
  await expect.soft(linhas).toContainText('Marcos Lima');
  await expect.soft(page.getByText(ABANDONADAS)).toBeVisible();

  // 2. O bloco da fila no Painel.
  const primeiro = page
    .getByRole('navigation')
    .first()
    .getByRole('listitem')
    .first()
    .getByRole('button')
    .first();
  await primeiro.click();
  await page.waitForURL(/\/painel$/);
  const fila = page.getByRole('article').filter({
    has: page.getByRole('heading', { name: /^Esperando a equipe agora/ }),
  });
  await expect(fila.getByRole('listitem').first()).toBeVisible();
  await fila.scrollIntoViewIfNeeded();
  await prova(page, 'painel-fila');
  await expect(fila.getByRole('listitem')).toHaveCount(1);
  await expect(fila).toContainText('Marcos Lima');
  await expect(fila).toContainText(ABANDONADAS);
});
