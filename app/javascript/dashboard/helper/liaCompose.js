// Autocompletar da LIA: completa o que o atendente começou a digitar com um texto do
// repertório da loja (respostas rápidas, salvas e o que a equipe repete). A busca é
// toda no navegador: o repertório chega uma vez por conversa e cada tecla só compara.

// Abaixo disso o começo ainda não diz qual texto o atendente quer ("Oi", "Bom dia").
export const MIN_TYPED_CHARS = 12;

const MARKS = /[̀-ͯ]/g;
const SPACE = /\s/;

// Uma letra sem acento e em minúscula: "É" e "e" casam.
const fold = char => char.normalize('NFD').replace(MARKS, '').toLowerCase();

// Onde o texto do repertório passa do que foi digitado, ou -1 se não começa igual.
// Acento, caixa e a quantidade de espaços/quebras de linha não contam.
export const prefixEnd = (text, typed) => {
  let i = 0;
  let j = 0;
  while (j < typed.length) {
    if (SPACE.test(typed[j])) {
      if (i < text.length && !SPACE.test(text[i])) return -1;
      while (j < typed.length && SPACE.test(typed[j])) j += 1;
      while (i < text.length && SPACE.test(text[i])) i += 1;
    } else {
      if (i >= text.length || fold(text[i]) !== fold(typed[j])) return -1;
      i += 1;
      j += 1;
    }
  }
  return i;
};

// O primeiro texto do repertório (já vem do mais oficial/usado para o menos) que
// começa com o que foi digitado e ainda tem o que acrescentar.
export const findCompletion = (library, typed) => {
  const start = String(typed || '').trimStart();
  if (start.trim().length < MIN_TYPED_CHARS) return null;
  const found = (library || []).find(item => {
    const end = prefixEnd(item.text, start);
    return end >= 0 && item.text.slice(end).trim().length > 0;
  });
  if (!found) return null;
  const rest = found.text.slice(prefixEnd(found.text, start));
  // Espaço digitado no fim já está no texto: o resto começa sem ele.
  const tail = SPACE.test(start.slice(-1)) ? rest.trimStart() : rest;
  return {
    text: found.text,
    source: found.source,
    rest: tail,
    full: start + tail,
  };
};
