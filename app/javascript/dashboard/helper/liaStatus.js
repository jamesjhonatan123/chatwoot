// Selo da LIA no cabecalho da conversa: chave de traducao e cor. A frase
// completa (motivo, ate quando, quem mudou) vem pronta da LIA.
const CHIP = {
  respondendo: 'LIA_STATUS.CHIP_ON',
  silencio: 'LIA_STATUS.CHIP_SILENT',
  desligada: 'LIA_STATUS.CHIP_OFF',
};

export const liaStatusTone = status => {
  if (status?.state === 'respondendo') return 'ok';
  if (status?.state === 'silencio') return 'warn';
  if (status?.state === 'desligada') return 'danger';
  return 'off';
};

// Em silencio, o selo leva o "ate ..." que a LIA ja escreveu no rotulo.
export const liaStatusChip = status => {
  const key = CHIP[status?.state];
  if (!key) return { key: 'LIA_STATUS.CHIP_UNKNOWN', until: null };
  if (status.state !== 'silencio') return { key, until: null };
  const ate = /até (.*?\d{2}:\d{2}|meia-noite)/.exec(status.label || '');
  return ate
    ? { key: 'LIA_STATUS.CHIP_SILENT_UNTIL', until: ate[1] }
    : { key, until: null };
};

export const liaStatusActionKey = status => {
  if (status?.action === 'ligar') return 'LIA_STATUS.ACTION_ON';
  if (status?.action === 'desligar') return 'LIA_STATUS.ACTION_OFF';
  return null;
};
