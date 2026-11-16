/*
 * Prints de ANTES da faixa, da fila e da passagem visível (não é teste de defeito: o
 * vermelho é o lia-avisos.spec.mjs na imagem de produção, que para no passo 1).
 *
 * Ponto de partida: a tela de login do Chatwoot.
 * Dados: os mesmos do lia-avisos.spec.mjs (conta "Loja E2E 8", Paula 74 min, Marcos
 *   20 min, Ana 5 min, ninguém respondeu).
 * Ação e resultado esperado:
 *   1. a lista de conversas (print "conversas");
 *   2. a atendente desliga a LIA pelo selo da conversa da Ana (print "faixa": na versão
 *      sem a mudança, só o selo muda);
 *   3. a conversa do Marcos depois de a LIA passar para a equipe (print "transferencia":
 *      na versão sem a mudança, a conversa não ganha nota, etiqueta nem prioridade).
 * Restauração do estado: o run.sh cria e apaga tudo (trap EXIT).
 * Como rodar (imagem e LIA sem a mudança):
 *   PROVAS_DIR=<repo>/.provas PROVAS_FAIXA=ANTES \
 *   CHATWOOT_IMAGE=developerlocfit/chatwoot-locfit:latest LIA_DIR=<LIA-2.0 em main> \
 *     cofre run GOOGLE_API_KEY=gemini-homolog -- e2e/lia/run.sh lia-avisos-antes.spec.mjs
 */
import { test, expect } from '@playwright/test';
import { SEED, entrar, prova } from './apoio.mjs';

const AVISOS = SEED.avisos || {};
const ESPERA = AVISOS.esperando || {};

test('antes: lista, LIA desligada e conversa passada para a equipe', async ({
  page,
}) => {
  const conta = `/app/accounts/${AVISOS.account_id}`;

  await entrar(page, 'teixeira@e2e.test');
  await expect(page.getByText('Paula Souza').first()).toBeVisible({
    timeout: 20_000,
  });
  await prova(page, 'conversas');

  await page.goto(`${conta}/conversations/${ESPERA['Ana Costa']}`);
  const chip = page.locator('[data-test-id="lia-status-chip"]');
  await expect(chip).toHaveText('LIA respondendo', { timeout: 15_000 });
  await chip.click();
  await page
    .getByRole('button', { name: 'Desligar a LIA nesta loja (volta sozinha)' })
    .click();
  await expect(chip).toHaveText(/LIA em silêncio/);
  await prova(page, 'faixa');

  await page.goto(`${conta}/conversations/${ESPERA['Marcos Lima']}`);
  await expect(page.getByText('Vocês entregam em Joinville?').first()).toBeVisible({
    timeout: 15_000,
  });
  await prova(page, 'transferencia');
});
