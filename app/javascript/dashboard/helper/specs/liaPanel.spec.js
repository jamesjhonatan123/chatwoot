// Formas de falhar: aba que mistura grupos, filtro de etapa que nao estreita, busca sensivel a
// acento, fila de outra loja aparecendo no filtro de loja, divisao por zero, delta sem base.
import {
  ago,
  autonomyDelta,
  filterRows,
  pct,
  waitingForStore,
} from '../liaPanel';

const rows = [
  {
    id: 1,
    contact_name: 'Patrícia Lima',
    inbox_name: 'Ponta Grossa',
    category: 'lia_only',
    stage: 'pagou',
  },
  {
    id: 2,
    contact_name: 'Rafael',
    inbox_name: 'Batel',
    category: 'handed_off',
    stage: 'recebeu_link',
    waiting_team: true,
  },
  {
    id: 3,
    contact_name: 'Bruno',
    inbox_name: 'Batel',
    category: 'lia_only',
    stage: 'recebeu_link',
  },
];

describe('liaPanel', () => {
  it('filters by tab, stage and accent-insensitive search', () => {
    expect(filterRows(rows, { tab: 'waiting' }).map(r => r.id)).toEqual([2]);
    expect(filterRows(rows, { tab: 'team' }).map(r => r.id)).toEqual([2]);
    expect(filterRows(rows, { tab: 'paid' }).map(r => r.id)).toEqual([1]);
    expect(
      filterRows(rows, { tab: 'with_lia', live: [{ id: 3 }] }).map(r => r.id)
    ).toEqual([3]);
    expect(filterRows(rows, { stage: 'recebeu_link' }).map(r => r.id)).toEqual([
      2, 3,
    ]);
    expect(filterRows(rows, { query: 'patricia' }).map(r => r.id)).toEqual([1]);
    expect(filterRows(rows, { query: '#3' }).map(r => r.id)).toEqual([3]);
  });

  it('keeps only the chosen store waiting queue', () => {
    const overview = {
      stores: [{ store_id: '58', inbox_ids: [7] }],
      waiting: {
        conversations: [
          { id: 1, inbox_id: 7 },
          { id: 2, inbox_id: 9 },
        ],
      },
    };
    expect(waitingForStore(overview, '58').map(r => r.id)).toEqual([1]);
    expect(waitingForStore(overview, null)).toHaveLength(2);
    expect(waitingForStore(overview, '999')).toEqual([]);
  });

  it('never divides by zero and only shows a delta with a previous period', () => {
    expect(pct(3, 0)).toBe(0);
    expect(pct(1, 3)).toBe(33);
    expect(
      autonomyDelta({
        summary: { autonomy_pct: 40 },
        previous: { autonomy_pct: 34.4, conversations: 9 },
      })
    ).toBe(6);
    expect(
      autonomyDelta({
        summary: { autonomy_pct: 40 },
        previous: { autonomy_pct: 0, conversations: 0 },
      })
    ).toBeNull();
  });

  it('formats waiting times', () => {
    expect(ago(0)).toBe('agora');
    expect(ago(12)).toBe('12 min');
    expect(ago(185)).toBe('3h 05');
    expect(ago(3000)).toBe('2d 2h');
  });
});
