// Formas de falhar: selo "respondendo" com a loja calada; selo sem "ate quando";
// botao de desligar que parece definitivo; estado desconhecido vira "respondendo".
import { liaStatusActionKey, liaStatusChip, liaStatusTone } from '../liaStatus';
import en from '../../i18n/locale/en/liaSuggestion.json';
import ptBR from '../../i18n/locale/pt_BR/liaSuggestion.json';

describe('liaStatus', () => {
  const calada = {
    state: 'silencio',
    label: 'Em silêncio até 19:00: desligada por Brenda',
    action: 'ligar',
  };

  it('em silencio, o selo diz ate quando', () => {
    expect(liaStatusChip(calada)).toEqual({
      key: 'LIA_STATUS.CHIP_SILENT_UNTIL',
      until: '19:00',
    });
    expect(
      liaStatusChip({
        state: 'silencio',
        label: 'Em silêncio até amanhã 08:00: horário de atendimento humano',
      }).until
    ).toBe('amanhã 08:00');
    expect(
      liaStatusChip({
        state: 'silencio',
        label: 'Em silêncio até seg 03/11 08:00: horário de atendimento humano',
      }).until
    ).toBe('seg 03/11 08:00');
    expect(
      liaStatusChip({
        state: 'silencio',
        label: 'Em silêncio até meia-noite: desligada por Rita',
      }).until
    ).toBe('meia-noite');
  });

  it('respondendo, desligada e desconhecido tem selos proprios', () => {
    expect(liaStatusChip({ state: 'respondendo' }).key).toBe(
      'LIA_STATUS.CHIP_ON'
    );
    expect(liaStatusChip({ state: 'desligada' }).key).toBe(
      'LIA_STATUS.CHIP_OFF'
    );
    expect(liaStatusChip({ state: null }).key).toBe('LIA_STATUS.CHIP_UNKNOWN');
    expect(liaStatusTone({ state: null })).toBe('off');
    expect(liaStatusTone(calada)).toBe('warn');
    expect(liaStatusTone({ state: 'desligada' })).toBe('danger');
  });

  it('o botao diz o alcance e que desligar volta sozinho', () => {
    expect(ptBR.LIA_STATUS[liaStatusActionKey(calada).split('.')[1]]).toBe(
      'Ligar a LIA agora nesta loja'
    );
    expect(ptBR.LIA_STATUS.ACTION_OFF).toBe(
      'Desligar a LIA nesta loja (volta sozinha)'
    );
    expect(liaStatusActionKey({ action: null })).toBeNull();
  });

  it('as duas linguas tem as mesmas chaves', () => {
    expect(Object.keys(ptBR.LIA_STATUS).sort()).toEqual(
      Object.keys(en.LIA_STATUS).sort()
    );
  });
});
