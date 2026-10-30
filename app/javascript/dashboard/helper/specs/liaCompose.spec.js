// Formas de falhar: começo curto demais completa qualquer coisa; acento, caixa ou
// espaço a mais impede o casamento; texto de várias linhas perde as quebras; o que foi
// digitado some ou é trocado pela versão do repertório; texto igual ao digitado é
// oferecido sem nada a acrescentar; a ordem do repertório (oficial antes) é ignorada;
// o meio do texto casa como se fosse o começo.
import { findCompletion, prefixEnd, MIN_TYPED_CHARS } from '../liaCompose';

const PLANOS =
  'Temos planos mensais a partir de R$ 189,90, com entrega e manutenção inclusas.';
const LISTA = 'Trabalhamos com:\n- bike\n- esteira\nQual você procura?';
const library = [
  { text: PLANOS, source: 'quick_reply' },
  { text: 'Temos planos anuais também, quer saber mais?', source: 'history' },
  { text: LISTA, source: 'canned' },
];

describe('liaCompose', () => {
  it('não completa antes do mínimo de letras', () => {
    expect(MIN_TYPED_CHARS).toBe(12);
    expect(findCompletion(library, 'Temos plano')).toBeNull();
    expect(findCompletion(library, 'Temos planos')).not.toBeNull();
  });

  it('casa sem acento, sem caixa e com espaço a mais', () => {
    const found = findCompletion(
      library,
      'TEMOS  PLANOS mensais a partir de r$ 189,90, com entrega e manutencao'
    );
    expect(found.text).toBe(PLANOS);
    expect(found.rest).toBe(' inclusas.');
  });

  it('mantém o que foi digitado e acrescenta só o resto', () => {
    const found = findCompletion(library, 'temos planos m');
    expect(found.full).toBe(
      'temos planos mensais a partir de R$ 189,90, com entrega e manutenção inclusas.'
    );
  });

  it('o primeiro do repertório vence (oficial antes do histórico)', () => {
    expect(findCompletion(library, 'Temos planos ').source).toBe('quick_reply');
    expect(findCompletion(library, 'Temos planos a').text).toBe(
      library[1].text
    );
  });

  it('espaço no fim não duplica', () => {
    expect(
      findCompletion(library, 'Temos planos ').rest.startsWith('mensais')
    ).toBe(true);
  });

  it('texto de várias linhas mantém as quebras no resto', () => {
    const found = findCompletion(library, 'Trabalhamos com: - bike');
    expect(found.rest).toBe('\n- esteira\nQual você procura?');
  });

  it('nada a acrescentar ou digitado maior que o texto não completa', () => {
    expect(
      findCompletion(
        [{ text: 'Temos planos mensais.', source: 'x' }],
        'Temos planos mensais.'
      )
    ).toBeNull();
    expect(findCompletion(library, `${PLANOS} E mais`)).toBeNull();
  });

  it('só casa pelo começo', () => {
    expect(findCompletion(library, 'planos mensais a partir')).toBeNull();
    expect(prefixEnd('abc', 'b')).toBe(-1);
  });

  it('repertório vazio ou ausente não quebra', () => {
    expect(findCompletion([], 'Temos planos mensais')).toBeNull();
    expect(findCompletion(undefined, 'Temos planos mensais')).toBeNull();
  });
});
