// Autocompletar da LIA: completa o que o atendente começou a digitar com um texto do
// repertório da loja (respostas rápidas, salvas e o que a equipe repete). A busca é
// toda no navegador: o repertório chega uma vez por conversa e cada tecla só compara.
//
// A comparação olha só letras e números: espaço, pontuação e emoji não contam, então
// "tudo certo." casa com "Tudo certo ." e "R$189" com "R$ 189". Sem texto exato, aceita
// um erro de digitação a cada FUZZY_KEYS_PER_ERROR letras (no máximo MAX_ERRORS), com
// o começo (EXACT_HEAD letras) sempre igual.

// Abaixo disso o começo ainda não diz qual texto o atendente quer ("Oi", "Bom dia").
export const MIN_TYPED_CHARS = 10;
export const FUZZY_KEYS_PER_ERROR = 10;
export const MAX_ERRORS = 2;
const EXACT_HEAD = 4;

const MARKS = /[̀-ͯ]/g;
const KEY = /[\p{L}\p{N}]/u;
const SPACE = /\s/;
const TRAILING_SPACE = /\s+$/;

// Uma letra sem acento e em minúscula: "É" e "e" casam.
const fold = char => char.normalize('NFD').replace(MARKS, '').toLowerCase();

// As letras e números do texto, já dobrados, com onde cada um começa e termina.
const keysOf = text => {
  const keys = [];
  const starts = [];
  const ends = [];
  let i = 0;
  while (i < text.length) {
    const char = String.fromCodePoint(text.codePointAt(i));
    const next = i + char.length;
    const folded = KEY.test(char) ? fold(char) : '';
    if (folded) {
      keys.push(folded);
      starts.push(i);
      ends.push(next);
    }
    i = next;
  }
  return { keys, starts, ends };
};

const sameHead = (typed, text, size) => {
  for (let k = 0; k < size; k += 1) if (typed[k] !== text[k]) return false;
  return true;
};

// Quantas letras do texto o digitado cobre sem erro, ou -1.
const exactCover = (typed, text) =>
  typed.length <= text.length && sameHead(typed, text, typed.length)
    ? typed.length
    : -1;

// Menor distância de edição entre o digitado e algum começo do texto, só na faixa em
// que ela pode caber em `allowed`. Devolve quantas letras do texto foram cobertas
// (a maior, no empate) ou -1.
const fuzzyCover = (typed, text, allowed) => {
  const m = typed.length;
  const limit = Math.min(text.length, m + allowed);
  let prev = Array.from({ length: limit + 1 }, (_, j) => j);
  for (let i = 1; i <= m; i += 1) {
    const row = [i];
    for (let j = 1; j <= limit; j += 1) {
      const cost = typed[i - 1] === text[j - 1] ? 0 : 1;
      row.push(Math.min(prev[j] + 1, row[j - 1] + 1, prev[j - 1] + cost));
    }
    prev = row;
  }
  let best = -1;
  for (let j = Math.max(0, m - allowed); j <= limit; j += 1) {
    if (prev[j] <= allowed && (best < 0 || prev[j] <= prev[best])) best = j;
  }
  return best;
};

// O que vem depois do digitado no texto, respeitando a pontuação que o atendente já
// escreveu; null quando não há o que acrescentar ou a pontuação cai no meio de uma
// palavra do texto ("d." contra "de").
const restAfter = (typed, text, map, covered) => {
  const end = covered ? map.ends[covered - 1] : 0;
  const typedTail = typed.slice(typed.search(/[^\p{L}\p{N}]*$/u));
  if (!typedTail) return text.slice(end);
  const next = covered < map.starts.length ? map.starts[covered] : text.length;
  const run = text.slice(end, next);
  if (!run && next < text.length) return null;
  const after = text.slice(next);
  if (!after.trim()) return null;
  const gap = SPACE.test(typedTail.slice(-1))
    ? ''
    : (run.match(TRAILING_SPACE) || [''])[0];
  return gap + after;
};

const completionFor = (item, typed, typedKeys, cover) => {
  const map = keysOf(item.text);
  const covered = cover(typedKeys, map.keys);
  if (covered < 0) return null;
  const rest = restAfter(typed, item.text, map, covered);
  return rest && rest.trim() ? { item, rest } : null;
};

// Onde o texto do repertório passa do que foi digitado, ou -1 se não começa igual.
export const prefixEnd = (text, typed) => {
  const map = keysOf(text);
  const covered = exactCover(keysOf(typed).keys, map.keys);
  if (covered < 0) return -1;
  return covered ? map.ends[covered - 1] : 0;
};

// O primeiro texto do repertório (já vem do mais oficial/usado para o menos) que
// começa com o que foi digitado e ainda tem o que acrescentar. O exato vence o
// parecido; entre parecidos, vale a ordem do repertório.
export const findCompletion = (library, typed) => {
  const start = String(typed || '').trimStart();
  if (start.trim().length < MIN_TYPED_CHARS) return null;
  const items = library || [];
  const typedKeys = keysOf(start).keys;

  let found = null;
  items.some(item => {
    found = completionFor(item, start, typedKeys, exactCover);
    return found;
  });

  const allowed = Math.min(
    MAX_ERRORS,
    Math.floor(typedKeys.length / FUZZY_KEYS_PER_ERROR)
  );
  if (!found && allowed > 0) {
    const fuzzy = (keys, text) =>
      sameHead(keys, text, EXACT_HEAD) ? fuzzyCover(keys, text, allowed) : -1;
    items.some(item => {
      found = completionFor(item, start, typedKeys, fuzzy);
      return found;
    });
  }
  if (!found) return null;

  return {
    text: found.item.text,
    source: found.item.source,
    rest: found.rest,
    full: start + found.rest,
  };
};
