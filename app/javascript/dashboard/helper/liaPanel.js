// Painel da LIA: regras de exibicao que nao dependem da tela (filtros, percentuais, gargalo).

export const STAGE_KEYS = {
  conversou: 'LIA_PANEL.STAGE.CONVERSOU',
  lia_respondeu: 'LIA_PANEL.STAGE.LIA_RESPONDEU',
  recebeu_link: 'LIA_PANEL.STAGE.RECEBEU_LINK',
  abriu_link: 'LIA_PANEL.STAGE.ABRIU_LINK',
  pagou: 'LIA_PANEL.STAGE.PAGOU',
};

export const CATEGORY_KEYS = {
  lia_only: 'LIA_PANEL.CATEGORY.LIA_ONLY',
  lia_and_team: 'LIA_PANEL.CATEGORY.LIA_AND_TEAM',
  team_only: 'LIA_PANEL.CATEGORY.TEAM_ONLY',
  handed_off: 'LIA_PANEL.CATEGORY.HANDED_OFF',
  campaign: 'LIA_PANEL.CATEGORY.CAMPAIGN',
  unanswered: 'LIA_PANEL.CATEGORY.UNANSWERED',
};

export const TABS = ['all', 'waiting', 'with_lia', 'team', 'paid'];

// Percentual inteiro de parte/total; 0 quando nao ha total.
export const pct = (part, total) =>
  total > 0 ? Math.round((100 * (part || 0)) / total) : 0;

// "agora", "12 min", "3h 05", "2d 4h".
export const ago = minutes => {
  const value = Math.max(0, Math.floor(minutes || 0));
  if (value < 1) return 'agora';
  if (value < 60) return `${value} min`;
  if (value < 1440)
    return `${Math.floor(value / 60)}h ${String(value % 60).padStart(2, '0')}`;
  return `${Math.floor(value / 1440)}d ${Math.floor((value % 1440) / 60)}h`;
};

export const minutesSince = (iso, now = new Date()) => {
  const at = iso ? new Date(iso) : null;
  if (!at || Number.isNaN(at.getTime())) return 0;
  return Math.max(0, Math.floor((now - at) / 60000));
};

// Diferenca de autonomia contra o periodo anterior, em pontos percentuais.
export const autonomyDelta = panel => {
  const now = panel?.summary?.autonomy_pct;
  const before = panel?.previous?.autonomy_pct;
  if (now == null || before == null || !panel?.previous?.conversations)
    return null;
  return Math.round(now - before);
};

const inTab = (row, tab, liveIds) => {
  if (tab === 'waiting') return Boolean(row.waiting_team);
  if (tab === 'with_lia') return liveIds.has(row.id);
  if (tab === 'team')
    return ['handed_off', 'lia_and_team', 'team_only'].includes(row.category);
  if (tab === 'paid') return row.stage === 'pagou';
  return true;
};

const normalize = value =>
  String(value || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();

// Lista filtrada por aba, etapa (clique no funil/gargalo) e busca por nome, caixa ou numero.
export const filterRows = (
  rows,
  { tab = 'all', stage = null, query = '', live = [] } = {}
) => {
  const liveIds = new Set(live.map(item => item.id));
  const needle = normalize(query).trim();
  return (rows || []).filter(row => {
    if (!inTab(row, tab, liveIds)) return false;
    if (stage && row.stage !== stage) return false;
    if (!needle) return true;
    return [row.contact_name, row.inbox_name, row.assignee_name, `#${row.id}`]
      .map(normalize)
      .some(text => text.includes(needle));
  });
};

// Fila "Esperando a equipe" do overview, so das caixas da loja escolhida.
export const waitingForStore = (overview, storeId) => {
  const rows = overview?.waiting?.conversations || [];
  if (!storeId) return rows;
  const store = (overview?.stores || []).find(
    item => item.store_id === storeId
  );
  const inboxes = new Set(store?.inbox_ids || []);
  return rows.filter(row => inboxes.has(row.inbox_id));
};

export const LINK_KEYS = {
  none: 'LIA_PANEL.LINK.NONE',
  sent: 'LIA_PANEL.LINK.SENT',
  clicked: 'LIA_PANEL.LINK.CLICKED',
  paid: 'LIA_PANEL.LINK.PAID',
};

// Total de quem espera a equipe: o count do Chatwoot (a lista vem cortada em 50) ou, com loja
// escolhida, o waiting_count dela.
export const waitingTotal = (overview, storeId) => {
  if (!overview) return 0;
  if (!storeId) return overview.waiting?.count || 0;
  const store = (overview.stores || []).find(item => item.store_id === storeId);
  return store?.waiting_count || 0;
};

// Celula de CSV: aspas dobradas e formula neutralizada (nome do WhatsApp com = + - @).
export const csvCell = value => {
  let text = String(value ?? '');
  if (/^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return `"${text.replace(/"/g, '""')}"`;
};
