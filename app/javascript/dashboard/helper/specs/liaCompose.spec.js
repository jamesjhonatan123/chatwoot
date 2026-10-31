// Formas de falhar: começo curto demais completa qualquer coisa; acento, caixa ou
// espaço a mais impede o casamento; texto de várias linhas perde as quebras; o que foi
// digitado some ou é trocado pela versão do repertório; texto igual ao digitado é
// oferecido sem nada a acrescentar; a ordem do repertório (oficial antes) é ignorada;
// o meio do texto casa como se fosse o começo; espaço ou pontuação diferente
// ("tudo certo." contra "tudo certo .", "R$189" contra "R$ 189") impede o casamento;
// emoji no texto trava a comparação; um erro de digitação derruba a sugestão; a
// tolerância a erro casa qualquer coisa (começo errado, erros demais); um texto
// parecido vence o exato; a pontuação digitada sai duplicada com a do texto; a
// pontuação digitada no meio de uma palavra do texto vira "d.e".
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
    expect(MIN_TYPED_CHARS).toBe(10);
    expect(findCompletion(library, 'Temos pla')).toBeNull();
    expect(findCompletion(library, 'Temos plan')).not.toBeNull();
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

  it('espaço antes da pontuação no texto não impede o casamento', () => {
    const lib = [
      { text: 'Tudo certo . Vou te enviar o contrato.', source: 'history' },
    ];
    expect(findCompletion(lib, 'tudo certo.').full).toBe(
      'tudo certo. Vou te enviar o contrato.'
    );
    expect(findCompletion(lib, 'tudo certo. ').full).toBe(
      'tudo certo. Vou te enviar o contrato.'
    );
    expect(findCompletion(lib, 'tudo certo').rest).toBe(
      ' . Vou te enviar o contrato.'
    );
  });

  it('valor colado ou separado casa igual', () => {
    const found = findCompletion(
      library,
      'Temos planos mensais a partir de R$189'
    );
    expect(found.text).toBe(PLANOS);
    expect(found.rest).toBe(',90, com entrega e manutenção inclusas.');
  });

  it('emoji e pontuação do texto não travam a comparação', () => {
    const lib = [
      { text: 'Perfeito! 😊 Vou separar a bike para você.', source: 'history' },
    ];
    expect(findCompletion(lib, 'Perfeito vou separar').rest).toBe(
      ' a bike para você.'
    );
  });

  it('aceita um erro de digitação e mantém o que foi digitado', () => {
    const lib = [
      { text: 'Temos bicicleta e esteira para alugar.', source: 'history' },
    ];
    const found = findCompletion(lib, 'Temos bicileta e es');
    expect(found.rest).toBe('teira para alugar.');
    expect(found.full).toBe('Temos bicileta e esteira para alugar.');
  });

  it('erro no começo ou erros demais não casam', () => {
    expect(findCompletion(library, 'Tenos planos mensais')).toBeNull();
    expect(findCompletion(library, 'Temos plnaos mnesais a prtir')).toBeNull();
  });

  it('o texto exato vence o parecido, mesmo vindo depois', () => {
    const lib = [
      { text: 'Temos bicicletas e esteiras.', source: 'quick_reply' },
      { text: 'Temos bicicleta e esteira para alugar.', source: 'history' },
    ];
    expect(findCompletion(lib, 'Temos bicicleta e es').source).toBe('history');
  });

  it('pontuação digitada no meio de uma palavra do texto não casa', () => {
    expect(findCompletion(library, 'Temos planos mensa.')).toBeNull();
  });

  it('repertório vazio ou ausente não quebra', () => {
    expect(findCompletion([], 'Temos planos mensais')).toBeNull();
    expect(findCompletion(undefined, 'Temos planos mensais')).toBeNull();
  });
});
