// Ajudantes das provas da LIA: login, consulta ao banco da LIA e print de prova.
import { execFileSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import path from 'node:path';

export const SEED = JSON.parse(process.env.E2E_SEED || '{}');
const PG = process.env.LIA_PG_CONTAINER || 'lia-e2e-lia-pg';

export const entrar = async (page, email) => {
  await page.goto('/app/login');
  await page.getByTestId('email_input').fill(email);
  await page.getByTestId('password_input').fill('Senha-e2e-123!');
  await page.getByTestId('submit_button').click();
  await page.waitForURL(/\/app\/accounts\/\d+\//);
};

// Linhas de uma consulta no banco descartável da LIA, colunas separadas por "|".
export const liaSql = sql =>
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
      sql,
    ],
    { encoding: 'utf8' }
  )
    .trim()
    .split('\n')
    .filter(Boolean);

// Print de prova com a faixa "ANTES"/"DEPOIS" dentro da imagem. Só grava quando
// PROVAS_DIR e PROVAS_FAIXA vêm do ambiente (rodada de prova); senão não faz nada.
export const prova = async (page, tela) => {
  const dir = process.env.PROVAS_DIR;
  const faixa = process.env.PROVAS_FAIXA;
  if (!dir || !faixa) return;
  mkdirSync(dir, { recursive: true });
  await page.evaluate(texto => {
    document.getElementById('prova-faixa')?.remove();
    const el = document.createElement('div');
    el.id = 'prova-faixa';
    el.textContent = texto;
    el.style.cssText =
      'position:fixed;top:0;left:0;right:0;z-index:2147483647;padding:6px 12px;' +
      'background:#111;color:#fff;font:700 14px/1.2 sans-serif;text-align:center;' +
      'letter-spacing:.08em;pointer-events:none';
    document.body.appendChild(el);
  }, faixa);
  await page.screenshot({
    path: path.join(dir, `${faixa.toLowerCase()}-${tela}.png`),
  });
  await page.evaluate(() => document.getElementById('prova-faixa')?.remove());
};
