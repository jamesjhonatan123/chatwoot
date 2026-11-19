/*
 * Painel da LIA: o primeiro item do menu mostra a eficiência da LIA, quem está com ela agora,
 * quem espera a equipe, os links e a lista das conversas, com os números da LIA de verdade.
 *
 * Pedido do dono (19/11/2026): "uma tela no chatwoot. O ideal é que seja Painel e fique acima
 *   de todas. Que mostre eficiência da LIA, autonomia, quantidade de links gerados, clickados,
 *   em que parte a pessoa parou, quais foram as etapas que mais travaram, Quantos sendo
 *   atendidos no momento, quantos esperando um humano, fila com quem é em ambos os casos."
 * Ponto de partida: a tela de login do Chatwoot e, depois dela, a lista de conversas (não o
 *   Painel).
 * Dados (seed.rb + run.sh, conta "Loja E2E 9", todas as mensagens de minutos atrás):
 *   Paula Souza recebeu o checkout, abriu e a LIA respondeu há 3 min (com a LIA agora);
 *   Marcos Lima pediu atendente, a LIA transferiu há 40 min e ninguém respondeu (esperando a
 *   equipe); Ana Costa veio de campanha (a equipe falou antes); Bruno Reis pagou o checkout
 *   só com a LIA.
 * Ação e resultado esperado exato:
 *   1. o primeiro link do menu é "Painel"; clicar nele abre /painel com o título "Painel da LIA";
 *   2. autonomia "67%" e "2 de 3 conversas atendidas só pela LIA" (a campanha fica fora);
 *      "1 de campanha fica fora da conta";
 *   3. "Com a LIA agora" = 1 e a fila lista Paula Souza; "Esperando a equipe" = 1 e a fila
 *      lista Marcos Lima;
 *   4. links "3 → 2" (dois checkouts e um produto mandados, dois abertos), "1 pago";
 *   5. motivo da transferência "Cliente pediu atendente"; gargalo "Recebeu o link e não abriu";
 *   6. a lista tem as 4 conversas; clicar na etapa "Pagou" do funil deixa só Bruno Reis;
 *      a busca "Marcos" deixa só Marcos Lima, e "Abrir" leva à conversa dele.
 *   Na imagem de produção sem a mudança falha no passo 1 (não existe o link "Painel").
 * Restauração do estado: o run.sh cria Chatwoot, LIA, bancos e Redis descartáveis e apaga
 *   tudo ao sair (trap EXIT), mesmo com falha. Nada toca produção nem homologação.
 *   Entre 0h e 1h de Brasília o "Hoje" não contém as mensagens de 50 min atrás: rode fora
 *   dessa hora.
 * Como rodar (da raiz do chatwoot-locfit, com as dependências em e2e/lia: npm ci):
 *   CHATWOOT_IMAGE=chatwoot-locfit:<commit> LIA_DIR=<LIA-2.0 com o endpoint do painel> \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh lia-painel.spec.mjs
 *   Vermelho esperado: CHATWOOT_IMAGE=developerlocfit/chatwoot-locfit:latest (produção).
 * Evidência: e2e/lia/artifacts/<imagem>-<data>/ (trace.zip, screenshots, logs).
 */
import { test, expect } from '@playwright/test';
import { SEED, entrar, prova } from './apoio.mjs';

const P = SEED.painel;

test('o Painel da LIA mostra autonomia, filas, links e a lista', async ({
  page,
}) => {
  await entrar(page, 'vera@e2e.test');
  await prova(page, 'menu');

  // 1. Primeiro item do menu.
  // Os itens de topo do menu são role="button" (SidebarGroupHeader.vue).
  const primeiro = page
    .getByRole('navigation')
    .first()
    .getByRole('listitem')
    .first()
    .getByRole('button')
    .first();
  await expect(primeiro).toHaveAccessibleName('Painel');
  await primeiro.click();
  await page.waitForURL(/\/painel$/);
  await expect(
    page.getByRole('heading', { name: 'Painel da LIA', level: 1 })
  ).toBeVisible();

  // Cada bloco do painel é um <article> com o título num heading.
  const bloco = nome =>
    page
      .getByRole('article')
      .filter({ has: page.getByRole('heading', { name: nome }) });

  // 2. Autonomia, sem a campanha.
  const autonomia = bloco(/^Autonomia da LIA$/);
  await expect(autonomia).toContainText('67%');
  await expect(autonomia).toContainText(
    '2 de 3 conversas atendidas só pela LIA'
  );
  await expect(autonomia).toContainText('1 de campanha fica fora da conta');

  // 3. As duas filas, com quem é.
  await expect(bloco(/^Com a LIA agora$/)).toContainText('1');
  const comLia = bloco(/^Com a LIA no momento/);
  await expect(comLia.getByRole('listitem')).toHaveCount(1);
  await expect(comLia).toContainText('Paula Souza');
  await expect(bloco(/^Esperando a equipe$/)).toContainText('1');
  const esperando = bloco(/^Esperando a equipe agora/);
  await expect(esperando.getByRole('listitem')).toHaveCount(1);
  await expect(esperando).toContainText('Marcos Lima');

  // 4. Links.
  const links = bloco(/^Links enviados → abertos$/);
  await expect(links).toContainText('3 → 2');
  await expect(links).toContainText('1 pago ·');

  // 5. Motivo e gargalo.
  await expect(bloco(/^Por que/)).toContainText('Cliente pediu atendente');
  await expect(bloco(/^Etapas que mais travaram$/)).toContainText(
    'Recebeu o link e não abriu'
  );
  await prova(page, 'painel');

  // 6. Lista, filtro pelo funil, busca e abrir.
  const lista = bloco(/^Conversas do período$/);
  const linhas = lista.getByRole('row').filter({ has: page.getByRole('cell') });
  await expect(linhas).toHaveCount(4);
  await bloco(/^Tendência$/).scrollIntoViewIfNeeded();
  await prova(page, 'painel-graficos-e-lista');
  await bloco(/^Funil/)
    .getByRole('button', { name: /Pagou/ })
    .click();
  await expect(linhas).toHaveCount(1);
  await expect(linhas).toContainText('Bruno Reis');
  await lista.getByRole('button', { name: /Limpar etapa/ }).click();
  await lista.getByRole('searchbox', { name: /Buscar/ }).fill('Marcos');
  await expect(linhas).toHaveCount(1);
  await lista
    .getByRole('link', { name: `Abrir #${P.conversas['Marcos Lima']}` })
    .click();
  await page.waitForURL(
    new RegExp(`/conversations/${P.conversas['Marcos Lima']}$`)
  );
});
