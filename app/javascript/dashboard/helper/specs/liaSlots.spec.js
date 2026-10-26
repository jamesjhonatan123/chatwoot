import { EditorState, Selection } from '@chatwoot/prosemirror-schema';
import {
  MessageMarkdownTransformer,
  messageSchema,
} from '@chatwoot/prosemirror-schema';
import {
  LIA_SLOTS,
  splitBySlots,
  findSlots,
  hasSlots,
  findSlotRange,
} from '../liaSlots';

const docFrom = markdown =>
  new MessageMarkdownTransformer(messageSchema).parse(markdown);

describe('liaSlots', () => {
  it('só reconhece os nomes da lista permitida', () => {
    expect(findSlots('[valor] [data] [hora] [número] [link] [e-mail]')).toEqual(
      LIA_SLOTS.map(name => `[${name}]`)
    );
    expect(findSlots('Pedido [123] e [cpf] e [Data]')).toEqual([]);
    expect(hasSlots('sem lacuna')).toBe(false);
  });

  it('não repete lacunas em findSlots', () => {
    expect(findSlots('[data] e de novo [data]')).toEqual(['[data]']);
  });

  it('quebra o texto em pedaços na ordem', () => {
    expect(splitBySlots('A [data] B [x] C [hora]')).toEqual([
      { text: 'A ', isSlot: false },
      { text: '[data]', isSlot: true },
      { text: ' B [x] C ', isSlot: false },
      { text: '[hora]', isSlot: true },
    ]);
  });

  describe('findSlotRange', () => {
    const doc = docFrom('Previsão [data].\n\nValor: [valor] ou [valor]');
    const textAt = range => doc.textBetween(range.from, range.to);

    it('acha a primeira lacuna desde o início', () => {
      expect(textAt(findSlotRange(doc))).toBe('[data]');
    });

    it('acha a próxima a partir do fim da anterior, em outro parágrafo', () => {
      const first = findSlotRange(doc);
      const second = findSlotRange(doc, first.to);
      expect(textAt(second)).toBe('[valor]');
      const third = findSlotRange(doc, second.to);
      expect(third.from).toBeGreaterThan(second.to);
      expect(findSlotRange(doc, third.to)).toBeNull();
    });

    it('devolve null sem lacuna permitida', () => {
      expect(findSlotRange(docFrom('Pedido [123]'))).toBeNull();
    });

    it('gera uma seleção de texto cobrindo a lacuna', () => {
      const { from, to } = findSlotRange(doc);
      const state = EditorState.create({ doc });
      const next = state.apply(
        state.tr.setSelection(
          Selection.fromJSON(doc, { type: 'text', anchor: from, head: to })
        )
      );
      expect(next.doc.textBetween(next.selection.from, next.selection.to)).toBe(
        '[data]'
      );
    });
  });
});
