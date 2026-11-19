// Revisao do PR #20 (Sonnet), escrita antes da correcao. Formas de falhar:
// 1. o indicador "Esperando a equipe" contava as linhas da lista (cortada em 50) e nao o total;
//    com loja escolhida, contava so as dela entre essas 50;
// 2. nome de contato comecando com = + - @ virava formula ao abrir o CSV na planilha;
// 3. a hora sem fuso ("...T17:00:00") era lida como hora local: tudo das ultimas 3 h virava "agora".
import { csvCell, minutesSince, waitingTotal } from '../liaPanel';

const overview = {
  waiting: {
    count: 120,
    conversations: Array.from({ length: 50 }, (_, i) => ({
      id: i,
      inbox_id: 1,
    })),
  },
  stores: [
    { store_id: '58', inbox_ids: [1], waiting_count: 50 },
    { store_id: '334', inbox_ids: [2], waiting_count: 70 },
  ],
};

describe('waitingTotal', () => {
  it('usa o total do Chatwoot, nao o tamanho da lista', () => {
    expect(waitingTotal(overview, '')).toBe(120);
  });
  it('com loja, usa o total da loja mesmo sem linha dela na lista', () => {
    expect(waitingTotal(overview, '334')).toBe(70);
  });
  it('sem overview, zero', () => {
    expect(waitingTotal(null, '')).toBe(0);
  });
});

describe('csvCell', () => {
  it('neutraliza formula e dobra aspas', () => {
    expect(csvCell('=HYPERLINK("x")')).toBe('"\'=HYPERLINK(""x"")"');
    expect(csvCell('+55 41')).toBe('"\'+55 41"');
    expect(csvCell('@ana')).toBe('"\'@ana"');
    expect(csvCell('Ana')).toBe('"Ana"');
    expect(csvCell(null)).toBe('""');
  });
});

describe('minutesSince', () => {
  it('le a hora com Z como UTC', () => {
    const now = new Date('2026-11-18T18:00:00Z');
    expect(minutesSince('2026-11-18T17:00:00Z', now)).toBe(60);
  });
});
