import { shallowMount } from '@vue/test-utils';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import { nextTick } from 'vue';
import { createStore } from 'vuex';
import ReplyBox from '../ReplyBox.vue';
import WhatsappTemplates from '../WhatsappTemplates/Modal.vue';

const CHANNELS = [
  { name: 'WhatsApp Cloud', inbox: { channel_type: 'Channel::Whatsapp' } },
  {
    name: 'Twilio WhatsApp',
    inbox: { channel_type: 'Channel::TwilioSms', medium: 'whatsapp' },
  },
  { name: 'API', inbox: { channel_type: 'Channel::Api' } },
  { name: 'Instagram', inbox: { channel_type: 'Channel::Instagram' } },
  { name: 'TikTok', inbox: { channel_type: 'Channel::Tiktok' } },
  { name: 'Facebook', inbox: { channel_type: 'Channel::FacebookPage' } },
  { name: 'Line', inbox: { channel_type: 'Channel::Line' } },
  { name: 'Telegram', inbox: { channel_type: 'Channel::Telegram' } },
  { name: 'Email', inbox: { channel_type: 'Channel::Email' } },
  { name: 'Web widget', inbox: { channel_type: 'Channel::WebWidget' } },
];

const exemptFromMessagingWindow = name =>
  ['WhatsApp Cloud', 'Twilio WhatsApp', 'API'].includes(name);

const REPLIABLE = {
  id: 1,
  inbox_id: 1,
  can_reply: true,
  status: 'open',
  meta: { sender: { id: 2 } },
  messages: [],
};

const buildStore = ({
  inbox,
  chat,
  templates,
  drafts = {},
  inboxes,
  isMetaMessageSendingDisabled = false,
}) =>
  createStore({
    state: {
      chat: { ...REPLIABLE, ...chat },
      replyEditorMode: REPLY_EDITOR_MODES.REPLY,
      drafts: { ...drafts },
    },
    mutations: {
      selectChat: (s, c) => {
        s.chat = c;
      },
      setReplyEditorMode: (s, mode) => {
        s.replyEditorMode = mode;
      },
      setDraft: (s, { key, message }) => {
        s.drafts = { ...s.drafts, [key]: message };
      },
    },
    actions: {
      'draftMessages/setReplyEditorMode': ({ commit }, { mode }) =>
        commit('setReplyEditorMode', mode),
      'draftMessages/set': ({ commit }, payload) => commit('setDraft', payload),
    },
    getters: {
      getSelectedChat: s => s.chat,
      getCurrentUser: () => ({ id: 7, name: 'Agent', accounts: [] }),
      getCurrentAccountId: () => 1,
      getMessageSignature: () => '',
      getUISettings: () => ({}),
      getLastEmailInSelectedChat: () => null,
      'globalConfig/get': () => ({}),
      'globalConfig/isMetaMessageSendingDisabled': () =>
        isMetaMessageSendingDisabled,
      'inboxes/getInbox': () => inboxId => ({
        id: inboxId,
        ...(inboxes?.[inboxId] || inbox),
      }),
      'inboxes/getWhatsAppTemplates': () => () => templates,
      'contacts/getContact': () => () => ({}),
      'draftMessages/get': s => key => s.drafts[key] || '',
      'draftMessages/getReplyEditorMode': s => s.replyEditorMode,
      'accounts/isFeatureEnabledonAccount': () => () => false,
      'accounts/getAccount': () => () => ({}),
      'portals/allPortals': () => [],
      'integrations/getUIFlags': () => ({ isFetching: false }),
    },
  });

const mountWith = ({
  inbox,
  chat,
  templates = [{ name: 'greeting' }],
  drafts,
  inboxes,
  isMetaMessageSendingDisabled,
  extraStubs = {},
}) => {
  const store = buildStore({
    inbox,
    chat,
    templates,
    drafts,
    inboxes,
    isMetaMessageSendingDisabled,
  });
  const wrapper = shallowMount(ReplyBox, {
    global: {
      plugins: [store],
      mocks: { $t: key => key },
      // The bottom panel sits inside a <Transition>, which shallowMount stubs
      // without rendering its children.
      stubs: { transition: false, ...extraStubs },
    },
  });
  return { wrapper, store };
};

const topPanel = wrapper =>
  wrapper.findComponent({ name: 'ReplyTopPanel' }).props();
const bottomPanel = wrapper =>
  wrapper.findComponent({ name: 'ReplyBottomPanel' }).props();
const editor = wrapper =>
  wrapper.findComponent({ name: 'WootMessageEditor' }).props();

describe('ReplyBox', () => {
  describe('Instagram incident restriction', () => {
    it('opens in note mode and restores only the private-note draft', async () => {
      const { wrapper, store } = mountWith({
        inbox: { channel_type: 'Channel::Instagram' },
        isMetaMessageSendingDisabled: true,
        drafts: {
          'draft-1-REPLY': 'unsent public reply',
          'draft-1-NOTE': 'incident note',
        },
      });
      await nextTick();

      expect(topPanel(wrapper).mode).toBe(REPLY_EDITOR_MODES.NOTE);
      expect(topPanel(wrapper).isReplyRestricted).toBe(true);
      expect(bottomPanel(wrapper).isOnPrivateNote).toBe(true);
      expect(editor(wrapper).editorId).toBe('draft-1-NOTE');
      expect(wrapper.vm.message).toBe('incident note');
      expect(store.getters['draftMessages/getReplyEditorMode']).toBe(
        REPLY_EDITOR_MODES.NOTE
      );
      expect(store.getters['draftMessages/get']('draft-1-REPLY')).toBe(
        'unsent public reply'
      );
    });

    it('preserves draft ownership when switching to a restricted conversation', async () => {
      const drafts = {
        'draft-1-REPLY': 'conversation A reply',
        'draft-1-NOTE': 'conversation A note',
        'draft-2-REPLY': 'conversation B reply',
        'draft-2-NOTE': 'conversation B note',
      };
      const { wrapper, store } = mountWith({
        inbox: { channel_type: 'Channel::WebWidget' },
        inboxes: {
          1: { channel_type: 'Channel::WebWidget' },
          2: { channel_type: 'Channel::Instagram' },
        },
        drafts,
        isMetaMessageSendingDisabled: true,
      });
      await nextTick();

      store.commit('selectChat', { ...REPLIABLE, id: 2, inbox_id: 2 });
      await nextTick();

      expect(editor(wrapper)).toMatchObject({
        editorId: 'draft-2-NOTE',
        modelValue: 'conversation B note',
      });
      Object.entries(drafts).forEach(([key, message]) => {
        expect(store.getters['draftMessages/get'](key)).toBe(message);
      });
    });
  });

  describe.each(CHANNELS)('$name', ({ name, inbox }) => {
    it('locks the composer and hides template sends when a bot owns a pending conversation', () => {
      const { wrapper } = mountWith({
        inbox,
        chat: {
          status: 'pending',
          meta: { sender: { id: 2 }, assignee_type: 'AgentBot' },
        },
      });

      expect(topPanel(wrapper).isReplyRestricted).toBe(true);
      expect(bottomPanel(wrapper).enableWhatsAppTemplates).toBe(false);
      expect(bottomPanel(wrapper).enableContentTemplates).toBe(false);
      // The note composer stays usable — this is a restriction, not a lockout.
      expect(topPanel(wrapper).isEditorDisabled).toBe(false);
    });

    it('opens directly in note mode when a bot already owns the pending conversation', () => {
      const { wrapper, store } = mountWith({
        inbox,
        chat: {
          can_reply: false,
          status: 'pending',
          meta: { sender: { id: 2 }, assignee_type: 'AgentBot' },
        },
      });

      expect(bottomPanel(wrapper).isOnPrivateNote).toBe(true);
      expect(store.getters['draftMessages/getReplyEditorMode']).toBe(
        REPLY_EDITOR_MODES.NOTE
      );
      expect(topPanel(wrapper).isEditorDisabled).toBe(false);
    });

    it('opens in reply mode for every other conversation', () => {
      const { wrapper, store } = mountWith({ inbox });

      expect(bottomPanel(wrapper).isOnPrivateNote).toBe(false);
      expect(store.getters['draftMessages/getReplyEditorMode']).toBe(
        REPLY_EDITOR_MODES.REPLY
      );
    });

    it.each(['open', 'resolved', 'snoozed'])(
      'leaves the composer open when a bot owns a %s conversation',
      status => {
        const { wrapper } = mountWith({
          inbox,
          chat: {
            status,
            meta: { sender: { id: 2 }, assignee_type: 'AgentBot' },
          },
        });

        expect(topPanel(wrapper).isReplyRestricted).toBe(false);
        expect(bottomPanel(wrapper).enableWhatsAppTemplates).toBe(true);
      }
    );

    it('leaves the composer open when a human owns a pending conversation', () => {
      const { wrapper } = mountWith({
        inbox,
        chat: {
          status: 'pending',
          meta: { sender: { id: 2 }, assignee_type: 'User' },
        },
      });

      expect(topPanel(wrapper).isReplyRestricted).toBe(false);
      expect(bottomPanel(wrapper).enableWhatsAppTemplates).toBe(true);
    });

    it('matches the existing messaging-window rule when no bot is involved', () => {
      const { wrapper } = mountWith({
        inbox,
        chat: { can_reply: false, status: 'resolved' },
      });

      const stillRepliable = exemptFromMessagingWindow(name);
      expect(topPanel(wrapper).isReplyRestricted).toBe(!stillRepliable);
      expect(bottomPanel(wrapper).enableWhatsAppTemplates).toBe(stillRepliable);
      // WhatsApp/API disable the editor and steer to templates; everywhere
      // else the composer falls back to a usable private note.
      expect(topPanel(wrapper).isEditorDisabled).toBe(stillRepliable);
    });
  });

  it('hides the template action when the inbox has no templates synced', () => {
    const { wrapper } = mountWith({
      inbox: { channel_type: 'Channel::Whatsapp' },
      chat: { can_reply: false, status: 'open' },
      templates: [],
    });

    expect(bottomPanel(wrapper).enableWhatsAppTemplates).toBe(false);
    expect(topPanel(wrapper).isReplyRestricted).toBe(false);
  });

  describe('drafts', () => {
    const DRAFTS = {
      'draft-1-REPLY': 'half typed reply',
      'draft-1-NOTE': 'a note',
    };

    it('loads the note draft while a bot owns the conversation', async () => {
      const { wrapper } = mountWith({
        inbox: { channel_type: 'Channel::WebWidget' },
        chat: {
          status: 'pending',
          meta: { sender: { id: 2 }, assignee_type: 'AgentBot' },
        },
        drafts: DRAFTS,
      });
      await nextTick();

      expect(editor(wrapper)).toMatchObject({
        editorId: 'draft-1-NOTE',
        modelValue: 'a note',
      });
    });

    it('leaves the saved reply draft intact and restores it on takeover', async () => {
      const { wrapper, store } = mountWith({
        inbox: { channel_type: 'Channel::WebWidget' },
        chat: {
          status: 'pending',
          meta: { sender: { id: 2 }, assignee_type: 'AgentBot' },
        },
        drafts: DRAFTS,
      });
      await nextTick();
      expect(store.getters['draftMessages/get']('draft-1-REPLY')).toBe(
        'half typed reply'
      );

      store.commit('selectChat', {
        ...REPLIABLE,
        status: 'open',
        meta: { sender: { id: 2 }, assignee_type: 'User' },
      });
      await nextTick();

      expect(editor(wrapper)).toMatchObject({
        editorId: 'draft-1-REPLY',
        modelValue: 'half typed reply',
      });
    });
  });

  it('offers content templates on Twilio WhatsApp when no bot owns the conversation', () => {
    const { wrapper } = mountWith({
      inbox: { channel_type: 'Channel::TwilioSms', medium: 'whatsapp' },
      chat: { can_reply: true, status: 'open' },
    });

    expect(bottomPanel(wrapper).enableContentTemplates).toBe(true);
  });

  describe('on selecting a conversation', () => {
    const selectChat = async chat => {
      const { wrapper, store } = mountWith({
        inbox: { channel_type: 'Channel::WebWidget' },
      });
      store.commit('selectChat', { ...REPLIABLE, id: 99, ...chat });
      await nextTick();
      return { wrapper, store };
    };

    it('switches to note mode when a bot owns a pending conversation', async () => {
      const { wrapper } = await selectChat({
        status: 'pending',
        meta: { sender: { id: 2 }, assignee_type: 'AgentBot' },
      });

      expect(bottomPanel(wrapper).isOnPrivateNote).toBe(true);
    });

    it('stays in reply mode when a human owns a pending conversation', async () => {
      const { wrapper } = await selectChat({
        status: 'pending',
        meta: { sender: { id: 2 }, assignee_type: 'User' },
      });

      expect(bottomPanel(wrapper).isOnPrivateNote).toBe(false);
    });

    it('closes an open template modal when a bot takes over the conversation', async () => {
      const { wrapper, store } = mountWith({
        inbox: { channel_type: 'Channel::Whatsapp' },
      });
      wrapper
        .findComponent({ name: 'ReplyBottomPanel' })
        .vm.$emit('selectWhatsappTemplate');
      await nextTick();
      expect(wrapper.findComponent(WhatsappTemplates).props('show')).toBe(true);

      store.commit('selectChat', {
        ...REPLIABLE,
        status: 'pending',
        meta: { sender: { id: 2 }, assignee_type: 'AgentBot' },
      });
      await nextTick();

      expect(wrapper.findComponent(WhatsappTemplates).props('show')).toBe(
        false
      );
    });

    it('returns to reply mode once the agent takes over', async () => {
      const { wrapper, store } = await selectChat({
        status: 'pending',
        meta: { sender: { id: 2 }, assignee_type: 'AgentBot' },
      });
      expect(bottomPanel(wrapper).isOnPrivateNote).toBe(true);

      store.commit('selectChat', {
        ...REPLIABLE,
        id: 99,
        status: 'open',
        meta: { sender: { id: 2 }, assignee_type: 'User' },
      });
      await nextTick();

      expect(bottomPanel(wrapper).isOnPrivateNote).toBe(false);
      expect(topPanel(wrapper).isReplyRestricted).toBe(false);
      expect(store.getters['draftMessages/getReplyEditorMode']).toBe(
        REPLY_EDITOR_MODES.REPLY
      );
    });

    it('keeps the agent in note mode after they chose it themselves', async () => {
      const { wrapper } = await selectChat({});
      wrapper
        .findComponent({ name: 'ReplyTopPanel' })
        .vm.$emit('setReplyMode', REPLY_EDITOR_MODES.NOTE);
      await nextTick();

      expect(bottomPanel(wrapper).isOnPrivateNote).toBe(true);
    });

    it('mirrors the forced note mode into the draftMessages store', async () => {
      const { store } = await selectChat({
        status: 'pending',
        meta: { sender: { id: 2 }, assignee_type: 'AgentBot' },
      });

      expect(store.getters['draftMessages/getReplyEditorMode']).toBe(
        REPLY_EDITOR_MODES.NOTE
      );
    });
  });
  describe('LIA suggestion Tab shortcut', () => {
    const useSuggestion = vi.fn(() => true);
    const BandStub = {
      name: 'LiaSuggestionBand',
      template: '<div />',
      methods: { useSuggestion },
    };
    const focusEditorInputField = vi.fn();
    const selectPlaceholder = vi.fn(() => false);
    const EditorStub = {
      name: 'WootMessageEditor',
      template: '<div />',
      methods: { focusEditorInputField, selectPlaceholder },
    };
    const mountForTab = async () => {
      const { wrapper } = mountWith({
        inbox: { channel_type: 'Channel::Api' },
        extraStubs: {
          LiaSuggestionBand: BandStub,
          WootMessageEditor: EditorStub,
        },
      });
      await nextTick();
      wrapper.vm.isFocused = true;
      return wrapper;
    };
    const tab = () => ({ shiftKey: false, preventDefault: vi.fn() });

    beforeEach(() => {
      useSuggestion.mockClear();
      selectPlaceholder.mockClear();
      focusEditorInputField.mockClear();
    });

    it('consumes Tab with preventDefault when the editor is empty and focused', async () => {
      const wrapper = await mountForTab();
      const event = tab();
      wrapper.vm.onLiaSuggestionTab(event);
      expect(useSuggestion).toHaveBeenCalledTimes(1);
      expect(event.preventDefault).toHaveBeenCalled();
    });

    it.each([
      'showCannedMenu',
      'showMentions',
      'showUserMentions',
      'showVariablesMenu',
      'showMacrosMenu',
    ])('does not consume Tab while %s is open', async menu => {
      const wrapper = await mountForTab();
      wrapper.vm[menu] = true;
      const event = tab();
      wrapper.vm.onLiaSuggestionTab(event);
      expect(useSuggestion).not.toHaveBeenCalled();
      expect(event.preventDefault).not.toHaveBeenCalled();
    });

    it('does not consume Tab when the editor has content or is not focused', async () => {
      const wrapper = await mountForTab();
      wrapper.vm.message = 'já escrevi algo';
      const event = tab();
      wrapper.vm.onLiaSuggestionTab(event);
      wrapper.vm.message = '';
      wrapper.vm.isFocused = false;
      wrapper.vm.onLiaSuggestionTab(event);
      expect(useSuggestion).not.toHaveBeenCalled();
      expect(event.preventDefault).not.toHaveBeenCalled();
    });

    it('does not prevent Tab when the band has nothing to use', async () => {
      useSuggestion.mockReturnValueOnce(false);
      const wrapper = await mountForTab();
      const event = tab();
      wrapper.vm.onLiaSuggestionTab(event);
      expect(event.preventDefault).not.toHaveBeenCalled();
    });

    it('puts the suggestion text in the editor', async () => {
      const wrapper = await mountForTab();
      wrapper.vm.onUseLiaSuggestion('Texto da LIA');
      await nextTick();
      expect(wrapper.vm.message).toBe('Texto da LIA');
      expect(focusEditorInputField).toHaveBeenCalled();
    });

    it('selects the first placeholder after using a text with slots', async () => {
      const wrapper = await mountForTab();
      wrapper.vm.onUseLiaSuggestion('Previsão [data].');
      await nextTick();
      expect(selectPlaceholder).toHaveBeenCalledWith();
    });

    it('does not select anything when the used text has no allowed slot', async () => {
      const wrapper = await mountForTab();
      wrapper.vm.onUseLiaSuggestion('Pedido [123] enviado');
      await nextTick();
      expect(selectPlaceholder).not.toHaveBeenCalled();
    });

    it('jumps to the next placeholder with Tab and consumes it', async () => {
      selectPlaceholder.mockReturnValueOnce(true);
      const wrapper = await mountForTab();
      wrapper.vm.message = 'Dia [data] às [hora]';
      const event = tab();
      wrapper.vm.onLiaSuggestionTab(event);
      expect(selectPlaceholder).toHaveBeenCalledWith({ afterCursor: true });
      expect(useSuggestion).not.toHaveBeenCalled();
      expect(event.preventDefault).toHaveBeenCalled();
    });

    it('does not consume Tab when there is no placeholder left', async () => {
      const wrapper = await mountForTab();
      wrapper.vm.message = 'Texto já completo';
      const event = tab();
      wrapper.vm.onLiaSuggestionTab(event);
      expect(event.preventDefault).not.toHaveBeenCalled();
    });

    it.each(['showCannedMenu', 'showMentions', 'showMacrosMenu'])(
      'does not jump to a placeholder while %s is open',
      async menu => {
        selectPlaceholder.mockReturnValue(true);
        const wrapper = await mountForTab();
        wrapper.vm.message = 'Dia [data]';
        wrapper.vm[menu] = true;
        const event = tab();
        wrapper.vm.onLiaSuggestionTab(event);
        expect(selectPlaceholder).not.toHaveBeenCalled();
        expect(event.preventDefault).not.toHaveBeenCalled();
        selectPlaceholder.mockReturnValue(false);
      }
    );
  });

  describe('LIA placeholder warning on send', () => {
    const mountForSend = async message => {
      const { wrapper } = mountWith({
        inbox: { channel_type: 'Channel::Api' },
      });
      await nextTick();
      wrapper.vm.message = message;
      const send = vi
        .spyOn(wrapper.vm, 'confirmOnSendReply')
        .mockImplementation(() => {});
      return { wrapper, send };
    };
    const warning = wrapper =>
      wrapper.find('[data-test-id="lia-missing-slots"]');

    it('blocks the first send with a slot left and lists it', async () => {
      const { wrapper, send } = await mountForSend('Previsão [data] e [valor]');
      await wrapper.vm.onSendReply();
      await nextTick();
      expect(send).not.toHaveBeenCalled();
      expect(warning(wrapper).text()).toContain('[data], [valor]');
    });

    it('sends on the second attempt', async () => {
      const { wrapper, send } = await mountForSend('Previsão [data]');
      await wrapper.vm.onSendReply();
      await wrapper.vm.onSendReply();
      await nextTick();
      expect(send).toHaveBeenCalledTimes(1);
      expect(warning(wrapper).exists()).toBe(false);
    });

    it('sends through the "send anyway" button', async () => {
      const { wrapper, send } = await mountForSend('Previsão [data]');
      await wrapper.vm.onSendReply();
      await nextTick();
      wrapper.vm.onSendAnyway();
      await nextTick();
      expect(send).toHaveBeenCalledTimes(1);
    });

    it('hides the warning once no slot is left', async () => {
      const { wrapper } = await mountForSend('Previsão [data]');
      await wrapper.vm.onSendReply();
      await nextTick();
      expect(warning(wrapper).exists()).toBe(true);
      wrapper.vm.message = 'Previsão amanhã';
      await nextTick();
      expect(warning(wrapper).exists()).toBe(false);
    });

    it.each(['Pedido sem lacuna', 'Código [123] e [abc]'])(
      'sends straight away without allowed slots: %s',
      async message => {
        const { wrapper, send } = await mountForSend(message);
        await wrapper.vm.onSendReply();
        expect(send).toHaveBeenCalledTimes(1);
        expect(warning(wrapper).exists()).toBe(false);
      }
    );
  });
});
