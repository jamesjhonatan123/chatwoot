// Formas de falhar: começo curto demais completa qualquer coisa; acento, caixa ou
// espaço a mais impede o casamento; texto de várias linhas perde as quebras; o que foi
// digitado some ou é trocado pela versão do repertório; texto igual ao digitado é
// oferecido sem nada a acrescentar; a ordem do repertório (oficial antes) é ignorada;
// o meio do texto casa como se fosse o começo; espaço ou pontuação diferente
// ("tudo certo." contra "tudo certo .", "R$189" contra "R$ 189") impede o casamento;
// emoji no texto trava a comparação; um erro de digitação derruba a sugestão; a
// tolerância a erro casa qualquer coisa (começo errado, erros demais); um texto
// parecido vence o exato; a pontuação digitada sai duplicada com a do texto; a
// pontuação digitada no meio de uma palavra do texto vira "d.e"; a frase começada sem
// as primeiras palavras do texto ("Locação é feita" contra "A locação é feita") não
// completa; pular palavras casa o meio de qualquer texto (pula demais, corta palavra,
// com poucas letras, com erro de digitação) ou passa na frente de quem casa pelo
// começo; o texto pulado volta para o que foi digitado.
// Atalho por palavra: dispara no meio de uma frase sendo escrita (longa, muitas
// palavras, várias linhas); dispara com pedaço curto demais ("ok", "a"); acento ou caixa
// impede o casamento; só casa o começo do atalho ou do texto, e não uma palavra do meio;
// casa o meio de uma palavra ("ede" em "rede"); basta um dos pedaços casar; o atalho
// vale o mesmo que o texto; o empate muda de ordem; resposta vazia ou igual ao digitado
// é oferecida; o fim de um texto longo casa com qualquer coisa.
import {
  continueGenerated,
  MIN_GENERATED_CHARS,
  findShortcut,
  MAX_SHORTCUT_CHARS,
  SHORTCUT_TEXT_WORDS,
  findCompletion,
  prefixEnd,
  MIN_TYPED_CHARS,
  MIN_SKIP_KEYS,
  MAX_SKIPPED_WORDS,
} from '../liaCompose';

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

  it('o meio de uma palavra não casa como começo', () => {
    expect(findCompletion(library, 'emos planos mensais a partir')).toBeNull();
    expect(prefixEnd('abc', 'b')).toBe(-1);
  });

  describe('frase começada sem as primeiras palavras do texto', () => {
    const SITE = {
      text: 'A locação é feita pelo nosso site: https://loc.fit/loja',
      source: 'history',
    };

    it('completa e mantém o que foi digitado', () => {
      const found = findCompletion([SITE], 'Locação é feita pelo');
      expect(found.rest).toBe(' nosso site: https://loc.fit/loja');
      expect(found.full).toBe(
        'Locação é feita pelo nosso site: https://loc.fit/loja'
      );
    });

    it(`pula até ${MAX_SKIPPED_WORDS} palavras do texto, não mais`, () => {
      const lib = [
        { text: 'Oi, então, olha, a locação é feita pelo site.', source: 'x' },
      ];
      expect(findCompletion(lib, 'a locação é feita pelo').rest).toBe(' site.');
      expect(findCompletion(lib, 'locação é feita pelo')).toBeNull();
    });

    it(`só depois de ${MIN_SKIP_KEYS} letras e sem erro de digitação`, () => {
      expect(MIN_SKIP_KEYS).toBe(15);
      expect(findCompletion([SITE], 'Locação é feita p')).toBeNull();
      expect(findCompletion([SITE], 'Locação é feita pe')).not.toBeNull();
      expect(findCompletion([SITE], 'Locaçao é fieta pelo nosso')).toBeNull();
    });

    it('quem casa pelo começo vem antes', () => {
      const lib = [
        SITE,
        { text: 'Locação é feita pelo app em até 2 dias.', source: 'history' },
      ];
      expect(findCompletion(lib, 'Locação é feita pelo').rest).toBe(
        ' app em até 2 dias.'
      );
    });
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

const REDE =
  'Você tem rede social? Se puder, manda o link ou @ do seu perfil 😊 A gente usa na análise.';
const FLEX =
  'Você prefere um plano mais flexível, sem fidelidade, ou o de 6 meses com desconto?';
const SEGUIR =
  '**Vamos seguir com a sua locação pra você treinar em casa?** O que falta: documentos.';
const canned = [
  { id: 10, short_code: 'Documentação solicitar rede social', content: REDE },
  { id: 11, short_code: 'Você prefere um plano mais flexível', content: FLEX },
  {
    id: 12,
    short_code: 'Fechamento - o que falta pra avançar',
    content: SEGUIR,
  },
  { id: 13, short_code: 'vazio', content: '   ' },
];

describe('findShortcut', () => {
  it('acha pela palavra em qualquer parte do atalho', () => {
    expect(findShortcut(canned, 'rede social').text).toBe(REDE);
    expect(findShortcut(canned, 'social').text).toBe(REDE);
    expect(findShortcut(canned, 'flexível').text).toBe(FLEX);
    expect(findShortcut(canned, 'plano flex').text).toBe(FLEX);
    expect(findShortcut(canned, 'rede social').source).toBe('canned_keyword');
    expect(findShortcut(canned, 'rede social').shortCode).toBe(
      canned[0].short_code
    );
  });

  it('acha pela palavra do começo do texto quando o atalho não tem', () => {
    expect(findShortcut(canned, 'vamos seguir').text).toBe(SEGUIR);
  });

  it('ignora acento e caixa', () => {
    expect(findShortcut(canned, 'FLEXIVEL').text).toBe(FLEX);
    expect(findShortcut(canned, 'documentacao').text).toBe(REDE);
  });

  it('casa só o começo de cada palavra', () => {
    expect(findShortcut(canned, 'ede')).toBeNull();
    expect(findShortcut(canned, 'ivel')).toBeNull();
  });

  it('exige que todos os pedaços casem', () => {
    expect(findShortcut(canned, 'rede bicicleta')).toBeNull();
  });

  it('não dispara com pedaço curto nem no meio de uma frase', () => {
    expect(findShortcut(canned, 'ok')).toBeNull();
    expect(findShortcut(canned, 'a rede')).toBeNull();
    expect(findShortcut(canned, 'rede social do seu perfil')).toBeNull();
    expect(findShortcut(canned, 'rede\nsocial')).toBeNull();
    expect(
      findShortcut(canned, `rede ${'s'.repeat(MAX_SHORTCUT_CHARS)}`)
    ).toBeNull();
  });

  it('aceita pedaço de 2 com número (modelo de equipamento)', () => {
    const list = [
      { id: 1, short_code: 'Esteira R1', content: 'A esteira R1.' },
    ];
    expect(findShortcut(list, 'r1').text).toBe('A esteira R1.');
    expect(findShortcut(list, 'es')).toBeNull();
  });

  it('o atalho vale mais que o texto', () => {
    const list = [
      {
        id: 1,
        short_code: 'boas vindas',
        content: 'Qual equipamento de rede você quer?',
      },
      { id: 2, short_code: 'rede', content: 'Manda sua rede social.' },
    ];
    expect(findShortcut(list, 'rede').text).toBe('Manda sua rede social.');
  });

  it('empate: pedaço no começo do atalho, depois atalho curto, depois o mais antigo', () => {
    const list = [
      { id: 5, short_code: 'Cobrança pix chave', content: 'Chave A' },
      { id: 4, short_code: 'pix', content: 'Chave B' },
      { id: 3, short_code: 'pix ponta grossa', content: 'Chave C' },
    ];
    expect(findShortcut(list, 'pix').text).toBe('Chave B');
    const twins = [
      { id: 9, short_code: 'pix', content: 'Nova' },
      { id: 2, short_code: 'pix', content: 'Antiga' },
    ];
    expect(findShortcut(twins, 'pix').text).toBe('Antiga');
  });

  it('não oferece resposta vazia nem igual ao digitado', () => {
    expect(findShortcut(canned, 'vazio')).toBeNull();
    const list = [{ id: 1, short_code: 'ok', content: 'Tudo certo' }];
    expect(findShortcut(list, 'tudo certo')).toBeNull();
  });

  it('o fim de um texto longo não casa', () => {
    const long = `${'palavra '.repeat(SHORTCUT_TEXT_WORDS)}escondida`;
    const list = [{ id: 1, short_code: 'longo', content: long }];
    expect(findShortcut(list, 'escondida')).toBeNull();
    expect(findShortcut(list, 'palavra').text).toBe(long);
  });
});

// Continuação escrita pela LIA. Formas de falhar: sumir quando o atendente digita por
// cima do texto apagado; continuar aparecendo depois de ele escrever outra coisa;
// entregar de novo o que já foi digitado; sobrar só espaço; quebrar com acento ou caixa.
describe('continueGenerated', () => {
  const generated = {
    typed: 'Todo o processo de locação é',
    rest: ' feito pelo nosso site.',
  };

  it('entrega o restante para o texto em que a LIA foi consultada', () => {
    expect(continueGenerated(generated, generated.typed)).toEqual({
      text: 'Todo o processo de locação é feito pelo nosso site.',
      source: 'lia',
      rest: ' feito pelo nosso site.',
      full: 'Todo o processo de locação é feito pelo nosso site.',
    });
  });

  it('segue valendo enquanto ele digita por cima, sem repetir o que já escreveu', () => {
    const found = continueGenerated(
      generated,
      'Todo o processo de locação é fei'
    );
    expect(found.rest).toBe('to pelo nosso site.');
    expect(found.full).toBe(
      'Todo o processo de locação é feito pelo nosso site.'
    );
    expect(
      continueGenerated(generated, 'todo o processo de locacao e FEITO').rest
    ).toBe(' pelo nosso site.');
  });

  it('some quando ele escreve outra coisa, apaga o começo ou termina o texto', () => {
    expect(
      continueGenerated(generated, 'Todo o processo de locação é rápido')
    ).toBeNull();
    expect(continueGenerated(generated, 'Todo o processo')).toBeNull();
    expect(
      continueGenerated(
        generated,
        'Todo o processo de locação é feito pelo nosso site.'
      )
    ).toBeNull();
    expect(continueGenerated({ typed: 'Ok', rest: '   ' }, 'Ok')).toBeNull();
    expect(continueGenerated(null, 'Ok')).toBeNull();
  });

  it('só pede à LIA a partir de 20 letras', () => {
    expect(MIN_GENERATED_CHARS).toBe(20);
  });
});
