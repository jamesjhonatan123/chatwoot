// Faixa "LIA parada" e fila "Esperando a equipe". Formas de falhar:
// - silencio do horario da equipe (a grade) acende a faixa o dia todo, sem ninguem
//   esperando, e a equipe aprende a ignorar;
// - LIA desligada por alguem nao aparece por nao ter cliente esperando ainda;
// - loja respondendo, ou estado indisponivel, vira "LIA parada";
// - o tempo de espera sai errado na virada da hora ou do dia, ou com data invalida;
// - o contador no titulo da aba se acumula: "(3) (2) Chatwoot".
import {
  bannerStores,
  bannerTone,
  titleWithCount,
  waitingFor,
} from '../liaOverview';

const store = attrs => ({
  store_id: '1',
  name: 'Batel',
  state: 'silencio',
  reason: 'excecao_off',
  label: 'Em silêncio até meia-noite: desligada por Brenda',
  waiting_count: 0,
  ...attrs,
});

describe('bannerStores', () => {
  it('shows a store someone turned off even with nobody waiting, in amber', () => {
    const [only] = bannerStores({ stores: [store()] });
    expect(only.tone).toBe('amber');
  });

  it('turns red when customers are waiting', () => {
    const list = bannerStores({ stores: [store({ waiting_count: 3 })] });
    expect(list[0].tone).toBe('red');
    expect(bannerTone(list)).toBe('red');
  });

  it('ignores the scheduled team hours unless someone is waiting', () => {
    expect(bannerStores({ stores: [store({ reason: 'grade' })] })).toEqual([]);
    expect(
      bannerStores({ stores: [store({ reason: 'grade', waiting_count: 1 })] })
    ).toHaveLength(1);
  });

  it('shows LIA turned off with no deadline', () => {
    const list = bannerStores({
      stores: [store({ state: 'desligada', reason: 'desligada' })],
    });
    expect(list).toHaveLength(1);
  });

  it('never shows a responding store or an unknown state', () => {
    expect(
      bannerStores({
        stores: [
          store({ state: 'respondendo', reason: 'normal', waiting_count: 4 }),
          store({ state: null, waiting_count: 4 }),
        ],
      })
    ).toEqual([]);
    expect(bannerStores(null)).toEqual([]);
  });

  it('is amber when every listed store has nobody waiting', () => {
    expect(bannerTone(bannerStores({ stores: [store(), store()] }))).toBe(
      'amber'
    );
  });
});

describe('waitingFor', () => {
  const now = new Date('2026-11-16T20:00:00Z');
  const ago = minutes => new Date(now - minutes * 60000).toISOString();

  it('formats minutes, hours and days', () => {
    expect(waitingFor(ago(34), now)).toEqual({ text: '34 min', tone: 'amber' });
    expect(waitingFor(ago(59), now).tone).toBe('amber');
    expect(waitingFor(ago(60), now)).toEqual({ text: '1h 00', tone: 'red' });
    expect(waitingFor(ago(74), now).text).toBe('1h 14');
    expect(waitingFor(ago(905), now).text).toBe('15h 05');
    expect(waitingFor(ago(60 * 24 * 2 + 180), now).text).toBe('2d 3h');
  });

  it('does not break on a missing or invalid date', () => {
    expect(waitingFor(null, now).text).toBe('');
    expect(waitingFor('ontem', now).text).toBe('');
  });
});

describe('titleWithCount', () => {
  it('adds, replaces and removes the count without stacking', () => {
    expect(titleWithCount('Chatwoot', 7)).toBe('(7) Chatwoot');
    expect(titleWithCount('(7) Chatwoot', 2)).toBe('(2) Chatwoot');
    expect(titleWithCount('(2) Chatwoot', 0)).toBe('Chatwoot');
  });
});
