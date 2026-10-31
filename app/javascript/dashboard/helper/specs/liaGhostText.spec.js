// Formas de falhar: o texto apagado aparece com o cursor no meio da frase ou com
// seleção; entra no documento (e daí na mensagem enviada ou no rascunho); fica na tela
// depois que a sugestão some; perde o espaço do começo e cola na palavra; ou é
// clicável/editável e desloca o cursor.
import {
  EditorState,
  Selection,
  MessageMarkdownTransformer,
  MessageMarkdownSerializer,
  messageSchema,
} from '@chatwoot/prosemirror-schema';
import { createGhostTextPlugin, refreshGhostText } from '../liaGhostText';

const stateWith = (markdown, ghost, selection = 'end') => {
  const plugin = createGhostTextPlugin(() => ghost.value);
  const doc = new MessageMarkdownTransformer(messageSchema).parse(markdown);
  const state = EditorState.create({ doc, plugins: [plugin] });
  const sel =
    typeof selection === 'function'
      ? selection(state.doc)
      : Selection.atEnd(state.doc);
  return { plugin, state: state.apply(state.tr.setSelection(sel)) };
};

const widgets = ({ plugin, state }) => plugin.props.decorations(state).find();

const render = deco => deco.type.toDOM();

describe('liaGhostText', () => {
  it('mostra o restante no cursor, no fim do texto', () => {
    const ghost = { value: ' Vou te enviar o contrato.' };
    const editor = stateWith('Tudo certo.', ghost);
    const [deco] = widgets(editor);
    expect(deco.from).toBe(editor.state.selection.head);
    const dom = render(deco);
    expect(dom.textContent).toBe(' Vou te enviar o contrato.');
    expect(dom.getAttribute('data-test-id')).toBe('lia-compose-ghost');
  });

  it('não fica clicável, editável nem lido duas vezes', () => {
    const dom = render(widgets(stateWith('Tudo certo.', { value: ' Ok' }))[0]);
    expect(dom.getAttribute('contenteditable')).toBe('false');
    expect(dom.getAttribute('aria-hidden')).toBe('true');
    expect(dom.className).toContain('pointer-events-none');
    expect(dom.className).toContain('select-none');
  });

  it('guarda o espaço do começo', () => {
    const dom = render(widgets(stateWith('Tudo certo.', { value: '  a' }))[0]);
    expect(dom.className).toContain('whitespace-pre-wrap');
  });

  it('nada com o cursor no meio da frase', () => {
    const editor = stateWith('Tudo certo.', { value: ' Ok' }, doc =>
      Selection.fromJSON(doc, { type: 'text', anchor: 3, head: 3 })
    );
    expect(widgets(editor)).toEqual([]);
  });

  it('nada com texto selecionado', () => {
    const editor = stateWith('Tudo certo.', { value: ' Ok' }, doc =>
      Selection.fromJSON(doc, {
        type: 'text',
        anchor: 1,
        head: doc.content.size - 1,
      })
    );
    expect(widgets(editor)).toEqual([]);
  });

  it('nada sem sugestão', () => {
    expect(widgets(stateWith('Tudo certo.', { value: '' }))).toEqual([]);
    expect(widgets(stateWith('Tudo certo.', { value: null }))).toEqual([]);
  });

  it('some quando a sugestão some, sem mudar o documento', () => {
    const ghost = { value: ' Ok' };
    const editor = stateWith('Tudo certo.', ghost);
    expect(widgets(editor)).toHaveLength(1);
    ghost.value = '';
    const tr = refreshGhostText(editor.state.tr);
    expect(tr.docChanged).toBe(false);
    const next = { plugin: editor.plugin, state: editor.state.apply(tr) };
    expect(widgets(next)).toEqual([]);
  });

  it('não entra no texto da mensagem', () => {
    const { state } = stateWith('Tudo certo.', { value: ' Vou te enviar.' });
    expect(MessageMarkdownSerializer.serialize(state.doc)).toBe('Tudo certo.');
  });
});
