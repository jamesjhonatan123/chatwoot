// Faixa "LIA parada" e fila "Esperando a equipe": o que mostrar e com que cor.
// As frases do estado (ate quando, quem desligou) vem prontas da LIA.

const HOUR = 60;
const DAY = 24 * HOUR;

// "34 min", "1h 14", "2d 3h". Acima de uma hora fica vermelho.
export const waitingFor = (sinceIso, now = new Date()) => {
  const since = sinceIso ? new Date(sinceIso) : null;
  if (!since || Number.isNaN(since.getTime()))
    return { text: '', tone: 'amber' };
  const minutes = Math.max(0, Math.floor((now - since) / 60000));
  let text;
  if (minutes < HOUR) text = `${minutes} min`;
  else if (minutes < DAY)
    text = `${Math.floor(minutes / HOUR)}h ${String(minutes % HOUR).padStart(2, '0')}`;
  else
    text = `${Math.floor(minutes / DAY)}d ${Math.floor((minutes % DAY) / HOUR)}h`;
  return { text, tone: minutes >= HOUR ? 'red' : 'amber' };
};

// Loja entra na faixa quando alguem desligou a LIA (com ou sem prazo). No horario da
// equipe (a grade) o silencio e o combinado: so entra se tem cliente esperando.
export const bannerStores = overview => {
  const stores = overview?.stores || [];
  return stores
    .filter(store => store.state && store.state !== 'respondendo')
    .filter(store => store.reason !== 'grade' || store.waiting_count > 0)
    .map(store => ({
      ...store,
      tone: store.waiting_count > 0 ? 'red' : 'amber',
    }));
};

export const bannerTone = stores =>
  stores.some(store => store.tone === 'red') ? 'red' : 'amber';

const COUNT_PREFIX = /^\(\d+\)\s/;

// "(7) Chatwoot": quem esta em outra aba ve que tem cliente esperando.
export const titleWithCount = (title, count) => {
  const base = String(title || '').replace(COUNT_PREFIX, '');
  return count > 0 ? `(${count}) ${base}` : base;
};

export const REASON_KEYS = {
  lia_transferiu: 'LIA_OVERVIEW.REASON_HANDOFF',
  lia_parada: 'LIA_OVERVIEW.REASON_PAUSED',
  sem_resposta: 'LIA_OVERVIEW.REASON_UNANSWERED',
};
