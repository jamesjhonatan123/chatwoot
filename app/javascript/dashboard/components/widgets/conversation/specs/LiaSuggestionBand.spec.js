import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import LiaSuggestionBand from '../LiaSuggestionBand.vue';
import ConversationApi from 'dashboard/api/inbox/conversation';
import ptBR from 'dashboard/i18n/locale/pt_BR/liaSuggestion.json';

vi.mock('dashboard/api/inbox/conversation', () => ({
  default: { getLiaSuggestion: vi.fn(), dismissLiaSuggestion: vi.fn() },
}));

const i18n = createI18n({
  legacy: false,
  locale: 'pt_BR',
  messages: { pt_BR: ptBR },
});

let counter = 0;
const answer = (source = 'canned', text = 'Olá!\nTudo bem?') => {
  counter += 1;
  ConversationApi.getLiaSuggestion.mockResolvedValue({
    data: { suggestion: { id: `id-${counter}`, text, source }, reason: 'ok' },
  });
};

// Id novo a cada resposta: ids tratados sobrevivem entre testes.
let optionsId = '';
const answerOptions = () => {
  counter += 1;
  optionsId = `00000000-0000-4000-8000-${String(counter).padStart(12, '0')}`;
  ConversationApi.getLiaSuggestion.mockResolvedValue({
    data: {
      suggestion: null,
      options: [
        { text: 'Opção A', source: 'canned' },
        { text: 'Opção B', source: 'history' },
        { text: 'Opção C', source: 'quick_reply' },
      ],
      options_id: optionsId,
      reason: 'options',
    },
  });
};
const answerReason = reason =>
  ConversationApi.getLiaSuggestion.mockResolvedValue({
    data: { suggestion: null, options: [], options_id: null, reason },
  });
const answerSlots = (text, slots) => {
  counter += 1;
  ConversationApi.getLiaSuggestion.mockResolvedValue({
    data: {
      suggestion: { id: `id-${counter}`, text, source: 'canned', slots },
    },
  });
};
const NOTICE = 'Sem sugestão segura para esta mensagem.';

const mountBand = async (props = {}) => {
  const wrapper = mount(LiaSuggestionBand, {
    props: { conversationId: 10, lastIncomingId: 1, ...props },
    global: { plugins: [i18n] },
  });
  vi.advanceTimersByTime(900);
  await flushPromises();
  return wrapper;
};

describe('LiaSuggestionBand', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.clearAllMocks();
    ConversationApi.dismissLiaSuggestion.mockResolvedValue({
      data: { ok: true },
    });
  });
  afterEach(() => vi.useRealTimers());

  it.each([
    ['canned', 'da resposta pronta'],
    ['quick_reply', 'da resposta rápida'],
    ['history', 'de uma resposta anterior do time'],
  ])('shows the header for source %s', async (source, label) => {
    answer(source);
    const wrapper = await mountBand();
    expect(wrapper.text()).toContain('Sugestão pronta');
    expect(wrapper.text()).toContain(label);
    expect(wrapper.text()).toContain('Tab');
  });

  it('is hidden on private note, with content in the editor and when resolved', async () => {
    answer();
    expect((await mountBand({ isPrivateNote: true })).find('p').exists()).toBe(
      false
    );
    answer();
    expect((await mountBand({ hasContent: true })).find('p').exists()).toBe(
      false
    );
    answer();
    expect((await mountBand({ isResolved: true })).find('p').exists()).toBe(
      false
    );
  });

  it('stays hidden when there is no suggestion', async () => {
    ConversationApi.getLiaSuggestion.mockResolvedValue({
      data: { suggestion: null, reason: 'no_pending' },
    });
    const wrapper = await mountBand();
    expect(wrapper.find('p').exists()).toBe(false);
  });

  it('emits use with the text and hides the band', async () => {
    answer('canned', 'Texto pronto');
    const wrapper = await mountBand();
    const useButton = wrapper.findAll('button').find(b => b.text() === 'Usar');
    await useButton.trigger('click');
    expect(wrapper.emitted('use')[0]).toEqual(['Texto pronto']);
    expect(wrapper.find('p').exists()).toBe(false);
  });

  it('useSuggestion returns false when nothing is shown', async () => {
    const wrapper = await mountBand({ hasContent: true });
    expect(wrapper.vm.useSuggestion()).toBe(false);
    expect(wrapper.emitted('use')).toBeUndefined();
  });

  it('calls dismiss and hides the band when clicking the x', async () => {
    answer();
    const wrapper = await mountBand();
    const id = `id-${counter}`;
    await wrapper
      .find('button[aria-label="Descartar sugestão"]')
      .trigger('click');
    await flushPromises();
    expect(ConversationApi.dismissLiaSuggestion).toHaveBeenCalledWith(10, id);
    expect(wrapper.find('p').exists()).toBe(false);
  });

  it('refetches when a new incoming message arrives and drops stale answers', async () => {
    answer('canned', 'primeira');
    const wrapper = await mountBand();
    expect(ConversationApi.getLiaSuggestion).toHaveBeenCalledTimes(1);

    let resolveOld;
    ConversationApi.getLiaSuggestion.mockReturnValueOnce(
      new Promise(resolve => {
        resolveOld = resolve;
      })
    );
    await wrapper.setProps({ lastIncomingId: 2 });
    vi.advanceTimersByTime(900);
    // A conversa muda antes da resposta chegar.
    answer('canned', 'da outra conversa');
    await wrapper.setProps({ conversationId: 11 });
    vi.advanceTimersByTime(900);
    await flushPromises();
    resolveOld({
      data: { suggestion: { id: 'velha', text: 'velha', source: 'canned' } },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('da outra conversa');
    expect(wrapper.text()).not.toContain('velha');
  });

  describe('options', () => {
    it('renders the options with their sources and no Tab hint', async () => {
      answerOptions();
      const wrapper = await mountBand();
      expect(wrapper.text()).toContain('Opções da LIA');
      expect(wrapper.text()).toContain('Opção A');
      expect(wrapper.text()).toContain('resposta pronta');
      expect(wrapper.text()).toContain('resposta anterior do time');
      expect(wrapper.text()).toContain('resposta rápida');
      expect(wrapper.text()).not.toContain('Tab');
      expect(wrapper.find('button[title="Opção B"]').exists()).toBe(true);
    });

    it('inserts the clicked option and hides the band', async () => {
      answerOptions();
      const wrapper = await mountBand();
      await wrapper.find('button[title="Opção B"]').trigger('click');
      expect(wrapper.emitted('use')).toEqual([['Opção B']]);
      expect(wrapper.text()).not.toContain('Opções da LIA');
    });

    it('dismisses all options with the options_id', async () => {
      answerOptions();
      const wrapper = await mountBand();
      await wrapper
        .find('button[aria-label="Descartar opções"]')
        .trigger('click');
      await flushPromises();
      expect(ConversationApi.dismissLiaSuggestion).toHaveBeenCalledWith(
        10,
        optionsId
      );
      expect(wrapper.text()).not.toContain('Opções da LIA');
    });

    it('does not consume Tab when there are only options', async () => {
      answerOptions();
      const wrapper = await mountBand();
      expect(wrapper.vm.useSuggestion()).toBe(false);
      expect(wrapper.emitted('use')).toBeUndefined();
    });

    it('is hidden with content in the editor', async () => {
      answerOptions();
      const wrapper = await mountBand({ hasContent: true });
      expect(wrapper.text()).not.toContain('Opções da LIA');
    });
  });

  describe('no safe suggestion notice', () => {
    it.each(['low_confidence', 'no_candidates'])(
      'shows the notice for %s',
      async reason => {
        answerReason(reason);
        const wrapper = await mountBand();
        expect(wrapper.text()).toContain(NOTICE);
      }
    );

    it.each([
      'ai_answering',
      'no_pending',
      'mode_off',
      'shadow',
      'not_found',
      'error',
      'disabled',
    ])('shows nothing for %s', async reason => {
      answerReason(reason);
      const wrapper = await mountBand();
      expect(wrapper.text()).toBe('');
    });

    it('hides the notice on private note, with content and when resolved', async () => {
      answerReason('low_confidence');
      expect((await mountBand({ isPrivateNote: true })).text()).toBe('');
      expect((await mountBand({ hasContent: true })).text()).toBe('');
      expect((await mountBand({ isResolved: true })).text()).toBe('');
    });
  });

  describe('lacunas', () => {
    const chips = wrapper =>
      wrapper.findAll('span.bg-n-amber-3').map(c => c.text());
    const hint = wrapper => wrapper.find('[data-test-id="lia-slots-hint"]');

    it('destaca só as lacunas permitidas e mostra o aviso', async () => {
      answerSlots('Previsão [data] do pedido [123] por [valor].', [
        'data',
        'valor',
      ]);
      const wrapper = await mountBand();
      expect(chips(wrapper)).toEqual(['[data]', '[valor]']);
      expect(wrapper.find('p').text()).toContain('pedido [123] por');
      expect(hint(wrapper).text()).toContain('complete os espaços');
    });

    it('não mostra chip nem aviso quando não há lacuna permitida', async () => {
      answerSlots('Pedido [123] a caminho', []);
      const wrapper = await mountBand();
      expect(chips(wrapper)).toEqual([]);
      expect(hint(wrapper).exists()).toBe(false);
    });

    it('destaca lacunas também nas opções', async () => {
      counter += 1;
      ConversationApi.getLiaSuggestion.mockResolvedValue({
        data: {
          suggestion: null,
          options: [
            { text: 'Chega em [data]', source: 'canned', slots: ['data'] },
            { text: 'Sem lacuna', source: 'history', slots: [] },
          ],
          options_id: `00000000-0000-4000-8000-${String(counter).padStart(12, '0')}`,
          reason: 'options',
        },
      });
      const wrapper = await mountBand();
      expect(chips(wrapper)).toEqual(['[data]']);
      expect(hint(wrapper).exists()).toBe(true);
    });

    it('emite o texto com as lacunas ao usar', async () => {
      answerSlots('Chega em [data]', ['data']);
      const wrapper = await mountBand();
      await wrapper
        .findAll('button')
        .find(b => b.text() === 'Usar')
        .trigger('click');
      expect(wrapper.emitted('use')[0]).toEqual(['Chega em [data]']);
    });
  });
});
