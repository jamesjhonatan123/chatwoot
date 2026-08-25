import { shallowMount } from '@vue/test-utils';
import { computed } from 'vue';
import ConversationCard from '../ConversationCard.vue';

// Este ConversationCard e o da nossa linhagem: pega o contato da store, nao por
// prop. A spec do upstream montava sem store nenhuma, o que aqui nem renderiza.
const contact = { current: {} };

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    getters: {
      'contacts/getContact': () => contact.current,
    },
  }),
  useMapGetter: key => {
    const values = {
      getSelectedChat: {},
      'inboxes/getInboxes': [],
      getCurrentAccountId: 1,
    };
    return computed(() => values[key]);
  },
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: {}, name: 'home' }),
  useRouter: () => ({ push: vi.fn() }),
}));

const defaultChat = {
  id: 1,
  labels: [],
  messages: [],
  priority: null,
  unread_count: 0,
  timestamp: 1700000000,
  created_at: 1700000000,
  meta: { sender: { id: 7 } },
};

const mountComponent = (chat, currentContact = {}) => {
  contact.current = {
    id: 7,
    name: 'Jane Doe',
    thumbnail: '',
    availability_status: 'offline',
    ...currentContact,
  };

  return shallowMount(ConversationCard, {
    props: { chat: { ...defaultChat, ...chat } },
    global: { stubs: { 'fluent-icon': true, 'woot-label': true } },
  });
};

describe('ConversationCard', () => {
  it('does not reserve the labels row when only a persisted SLA policy id is present', () => {
    const wrapper = mountComponent({ sla_policy_id: 1, applied_sla: null });

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(false);
  });

  it('shows the labels row when an active applied SLA is present', () => {
    const wrapper = mountComponent({
      sla_policy_id: 1,
      applied_sla: { id: 1 },
    });

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(true);
  });

  it('does not reserve the labels row when the contact is blocked', () => {
    const wrapper = mountComponent(
      { sla_policy_id: 1, applied_sla: { id: 1 } },
      { blocked: true }
    );

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(false);
  });
});
