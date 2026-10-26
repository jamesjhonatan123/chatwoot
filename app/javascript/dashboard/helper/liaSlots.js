// Lacunas "[slot]" que a LIA deixa nos textos sugeridos. Só os nomes desta lista
// contam: colchetes digitados normalmente pelo atendente não são lacunas.
export const LIA_SLOTS = ['valor', 'data', 'hora', 'número', 'link', 'e-mail'];

const SLOT_PATTERN = `\\[(${LIA_SLOTS.join('|')})\\]`;

// Sempre cria um RegExp novo: regex global guarda estado (lastIndex).
const slotRegex = () => new RegExp(SLOT_PATTERN, 'g');

// Quebra o texto em pedaços { text, isSlot }, na ordem em que aparecem.
export const splitBySlots = (text = '') => {
  const parts = [];
  let last = 0;
  [...String(text).matchAll(slotRegex())].forEach(match => {
    if (match.index > last) {
      parts.push({ text: text.slice(last, match.index), isSlot: false });
    }
    parts.push({ text: match[0], isSlot: true });
    last = match.index + match[0].length;
  });
  if (last < text.length) parts.push({ text: text.slice(last), isSlot: false });
  return parts;
};

// Lacunas permitidas presentes no texto, sem repetir, na ordem de aparição.
export const findSlots = (text = '') => [
  ...new Set([...String(text).matchAll(slotRegex())].map(match => match[0])),
];

export const hasSlots = text => findSlots(text).length > 0;

// Acha a primeira lacuna que começa em `fromPos` ou depois, num documento
// ProseMirror. Devolve { from, to } em posições do documento, ou null.
export const findSlotRange = (doc, fromPos = 0) => {
  let found = null;
  doc.descendants((node, pos) => {
    if (found) return false;
    if (!node.isText) return true;
    const match = [...node.text.matchAll(slotRegex())].find(
      m => pos + m.index >= fromPos
    );
    if (match) {
      found = {
        from: pos + match.index,
        to: pos + match.index + match[0].length,
      };
    }
    return !found;
  });
  return found;
};
