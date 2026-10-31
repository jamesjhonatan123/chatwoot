// Texto apagado do autocompletar da LIA, desenhado no cursor como no Copilot. É só
// decoração do ProseMirror: não entra no documento, então não vai na mensagem, no
// rascunho nem no texto que o autocompletar compara.
import { Plugin, PluginKey } from 'prosemirror-state';
import { Decoration, DecorationSet } from 'prosemirror-view';

const ghostTextKey = new PluginKey('liaGhostText');

const GHOST_CLASS =
  'pointer-events-none select-none whitespace-pre-wrap text-n-slate-9';

// Só no fim do parágrafo, sem seleção: com o cursor no meio da frase o restante
// apareceria no lugar errado.
const ghostPosition = ({ selection }) => {
  if (!selection.empty) return null;
  const { $head } = selection;
  if (!$head.parent.isTextblock) return null;
  return $head.parentOffset === $head.parent.content.size ? $head.pos : null;
};

const ghostElement = text => () => {
  const span = document.createElement('span');
  span.className = GHOST_CLASS;
  span.textContent = text;
  span.setAttribute('contenteditable', 'false');
  // A dica abaixo do editor já anuncia a sugestão para leitor de tela.
  span.setAttribute('aria-hidden', 'true');
  span.setAttribute('data-test-id', 'lia-compose-ghost');
  return span;
};

// `getText` devolve o restante a mostrar (ou vazio). Como ele vive fora do estado do
// editor, quem muda o texto chama `refreshGhostText` para redesenhar.
export const createGhostTextPlugin = getText =>
  new Plugin({
    key: ghostTextKey,
    props: {
      decorations(state) {
        const text = getText();
        const pos = text ? ghostPosition(state) : null;
        if (pos === null) return DecorationSet.empty;
        return DecorationSet.create(state.doc, [
          Decoration.widget(pos, ghostElement(text), {
            side: 1,
            key: `lia-ghost:${text}`,
            ignoreSelection: true,
          }),
        ]);
      },
    },
  });

export const refreshGhostText = tr =>
  tr.setMeta(ghostTextKey, true).setMeta('addToHistory', false);
