// Autocompletar da LIA: completa o que o atendente começou a digitar com um texto do
// repertório da loja (respostas rápidas, salvas e o que a equipe repete). A busca é
// toda no navegador: o repertório chega uma vez por conversa e cada tecla só compara.
//
// A comparação olha só letras e números: espaço, pontuação e emoji não contam, então
// "tudo certo." casa com "Tudo certo ." e "R$189" com "R$ 189". Sem texto exato, aceita
// um erro de digitação a cada FUZZY_KEYS_PER_ERROR letras (no máximo MAX_ERRORS), com
// o começo (EXACT_HEAD letras) sempre igual. Sem nada pelo começo, casa a partir da 2ª
// palavra do texto em diante (até MAX_SKIPPED_WORDS pulam), sem erro: "Locação é
// feita" completa "A locação é feita pelo nosso site".

// Abaixo disso o começo ainda não diz qual texto o atendente quer ("Oi", "Bom dia").
export const MIN_TYPED_CHARS = 10;
export const FUZZY_KEYS_PER_ERROR = 10;
export const MAX_ERRORS = 2;
const EXACT_HEAD = 4;
// Pular palavras casa mais coisa; com menos letras que isso, a sugestão erra mais.
export const MIN_SKIP_KEYS = 15;
export const MAX_SKIPPED_WORDS = 3;

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

// O digitado casado sem erro a partir da 2ª até a (MAX_SKIPPED_WORDS + 1)ª palavra do
// texto; o resto é o que vem depois, e as palavras puladas ficam de fora.
const skippedCompletionFor = (item, typed, typedKeys) => {
  const map = keysOf(item.text);
  let skipped = 0;
  for (let k = 1; k < map.keys.length && skipped < MAX_SKIPPED_WORDS; k += 1) {
    if (map.starts[k] !== map.ends[k - 1]) {
      skipped += 1;
      const covered = exactCover(typedKeys, map.keys.slice(k));
      if (covered >= 0) {
        const rest = restAfter(typed, item.text, map, k + covered);
        if (rest && rest.trim()) return { item, rest };
      }
    }
  }
  return null;
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
// parecido, e os dois vencem o casado pulando palavras; em cada um, vale a ordem do
// repertório.
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
  if (!found && typedKeys.length >= MIN_SKIP_KEYS) {
    items.some(item => {
      found = skippedCompletionFor(item, start, typedKeys);
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

// Abaixo disso a LIA não ganha do repertório (medido em 444 respostas reais, 10/11/2026).
export const MIN_GENERATED_CHARS = 20;

// Continuação escrita pela LIA (`generated` = { typed, rest }, pedida quando o texto era
// `typed`) para o que está no editor agora. Segue valendo enquanto o atendente digita
// POR CIMA do texto apagado: o que ele já escreveu sai do restante. Diferença de caixa,
// acento ou espaço no fim não derruba; qualquer outra letra derruba.
export const continueGenerated = (generated, typed) => {
  if (!generated?.rest || !generated.typed) return null;
  const now = String(typed || '');
  const full = generated.typed + generated.rest;
  if (now.length < generated.typed.length || now.length >= full.length) {
    return null;
  }
  const same = (a, b) =>
    a.length === b.length &&
    [...a].every((char, i) => fold(char) === fold(b[i]));
  if (!same(now, full.slice(0, now.length))) return null;
  const rest = full.slice(now.length);
  if (!rest.trim()) return null;
  return { text: now + rest, source: 'lia', rest, full: now + rest };
};

// Atalho por palavra: o atendente digita um pedaço de palavra da resposta pronta
// ("rede social", "flexível", "vamos seguir") e ela inteira vem com Tab. Cada pedaço
// casa o começo de uma palavra em qualquer parte do atalho (vale mais) ou do começo do
// texto; todos precisam casar. Só para o começo de uma mensagem curta: depois disso o
// atendente está escrevendo, não procurando.
export const MAX_SHORTCUT_FRAGMENTS = 3;
export const MAX_SHORTCUT_CHARS = 30;
export const MIN_FRAGMENT_KEYS = 3;
// Palavras do texto que contam na busca: as do fim de um texto longo casariam com tudo.
export const SHORTCUT_TEXT_WORDS = 40;
const CODE_WEIGHT = 3;
const TEXT_WEIGHT = 1;

const wordsOf = text => {
  const { keys, starts, ends } = keysOf(String(text || ''));
  const words = [];
  keys.forEach((key, k) => {
    if (k > 0 && starts[k] === ends[k - 1]) words[words.length - 1] += key;
    else words.push(key);
  });
  return words;
};

// Compara posição a posição; a primeira diferença decide.
const outranks = (a, b) => {
  const k = a.findIndex((value, i) => value !== b[i]);
  return k >= 0 && a[k] > b[k];
};

const fragmentOk = fragment =>
  fragment.length >= MIN_FRAGMENT_KEYS ||
  (fragment.length === 2 && /\d/.test(fragment));

// A resposta pronta que os pedaços digitados apontam, ou null. `canned` é a lista do
// Chatwoot ({ id, short_code, content }); o empate fica com quem tem o pedaço no começo
// do atalho, depois o atalho mais curto, depois o cadastrado primeiro.
export const findShortcut = (canned, typed) => {
  const raw = String(typed || '').trim();
  if (!raw || raw.length > MAX_SHORTCUT_CHARS || /\n/.test(raw)) return null;
  const fragments = wordsOf(raw);
  if (!fragments.length || fragments.length > MAX_SHORTCUT_FRAGMENTS)
    return null;
  if (!fragments.every(fragmentOk)) return null;

  let best = null;
  (canned || []).forEach(item => {
    const content = String(item?.content || '');
    if (!content.trim()) return;
    const code = wordsOf(item.short_code);
    const text = wordsOf(content).slice(0, SHORTCUT_TEXT_WORDS);
    let score = 0;
    const all = fragments.every(fragment => {
      const starts = word => word.startsWith(fragment);
      if (code.some(starts)) score += CODE_WEIGHT;
      else if (text.some(starts)) score += TEXT_WEIGHT;
      else return false;
      return true;
    });
    if (!all) return;
    if (wordsOf(content).join(' ') === fragments.join(' ')) return;
    const head = code.length
      ? fragments.filter(f => code[0].startsWith(f)).length
      : 0;
    const rank = [score, head, -code.length, -Number(item.id || 0)];
    const better = !best || outranks(rank, best.rank);
    if (better) best = { item, rank };
  });
  if (!best) return null;
  return {
    text: best.item.content,
    source: 'canned_keyword',
    shortCode: best.item.short_code,
    rest: '',
    full: best.item.content,
  };
};
