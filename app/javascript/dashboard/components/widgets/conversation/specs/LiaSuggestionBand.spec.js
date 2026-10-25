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
});
