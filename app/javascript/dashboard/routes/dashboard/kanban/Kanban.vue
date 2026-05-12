<template>
  <div
    class="flex flex-col h-full overflow-hidden bg-slate-50 dark:bg-slate-900"
  >
    <div
      class="flex items-center justify-between px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-200 dark:border-slate-800"
    >
      <div class="flex items-center gap-4">
        <h1 class="text-xl font-semibold text-slate-800 dark:text-slate-100">
          {{ $t('KANBAN.HEADER') }}
        </h1>
        <div class="flex p-1 bg-slate-100 dark:bg-slate-800 rounded-lg">
          <button
            v-for="tab in ['labels', 'teams']"
            :key="tab"
            @click="switchTab(tab)"
            class="px-3 py-1 text-sm font-medium rounded-md transition-colors"
            :class="
              activeTab === tab
                ? 'bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 shadow-sm'
                : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'
            "
          >
            {{ $t(`KANBAN.TABS.${tab.toUpperCase()}`) || tab }}
          </button>
        </div>
      </div>
      <Button
        icon="i-lucide-settings"
        variant="outline"
        size="sm"
        @click="openSettings"
      >
        {{ $t('KANBAN.SETTINGS') || 'Settings' }}
      </Button>
    </div>

    <div class="flex flex-1 p-6 overflow-x-auto gap-4">
      <div
        v-for="status in statuses"
        :key="status.key"
        class="flex flex-col min-w-[320px] w-[320px] bg-slate-100 dark:bg-slate-800 rounded-lg h-full"
      >
        <div
          class="flex items-center justify-between p-3 border-b border-slate-200 dark:border-slate-700"
        >
          <div class="flex items-center gap-2">
            <span
              class="font-medium text-slate-700 dark:text-slate-200 capitalize"
            >
              {{ status.label }}
            </span>
            <span
              class="px-2 py-0.5 text-xs font-medium bg-slate-200 dark:bg-slate-700 rounded-full text-slate-600 dark:text-slate-300"
            >
              {{ getColumnCount(status) }}
            </span>
          </div>
        </div>

        <div
          class="flex-1 p-2 overflow-y-auto space-y-2"
          @scroll.passive="event => onColumnScroll(event, status)"
        >
          <div v-if="isLoading" class="flex justify-center py-4">
            <spinner />
          </div>

          <template v-else>
            <draggable
              v-model="conversations[status.key]"
              group="conversations"
              item-key="id"
              class="flex-1 min-h-[200px] space-y-2"
              @change="event => onDragChange(event, status.key)"
            >
              <template #item="{ element }">
                <conversation-card
                  :key="element.id"
                  :chat="element"
                  :hide-inbox-name="false"
                  :hide-thumbnail="false"
                  :disable-link="true"
                  class="bg-white dark:bg-slate-900 shadow-sm hover:shadow-md transition-shadow duration-200 cursor-move"
                  @click="openPreview(element)"
                />
              </template>
            </draggable>

            <div
              v-if="!conversations[status.key]?.length"
              class="flex flex-col items-center justify-center h-32 text-slate-400 dark:text-slate-500"
            >
              <p class="text-sm">{{ $t('KANBAN.NO_CONVERSATIONS') }}</p>
            </div>

            <div
              v-if="isColumnLoadingMore(status.key)"
              class="flex justify-center py-3"
            >
              <spinner />
            </div>
          </template>
        </div>
      </div>
    </div>

    <Modal
      v-if="showSettingsModal"
      :show="showSettingsModal"
      @close="showSettingsModal = false"
    >
      <div class="flex flex-col h-full">
        <div
          class="flex items-center justify-between px-6 py-4 border-b border-slate-100 dark:border-slate-800"
        >
          <h3 class="text-base font-medium text-slate-800 dark:text-slate-100">
            {{ $t('KANBAN.SETTINGS_TITLE') || 'Configure Columns' }}
          </h3>
        </div>

        <div class="p-6 overflow-y-auto max-h-[60vh]">
          <p class="text-sm text-slate-500 dark:text-slate-400 mb-4">
            {{
              $t('KANBAN.SETTINGS_DESCRIPTION') ||
              'Select and drag to reorder columns'
            }}
          </p>

          <!-- Labels Settings -->
          <div v-if="activeTab === 'labels'" class="space-y-2">
            <draggable
              v-model="orderedLabels"
              item-key="title"
              handle=".drag-handle"
              class="space-y-2"
            >
              <template #item="{ element: label }">
                <div
                  class="flex items-center gap-3 p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 cursor-default"
                >
                  <span
                    class="drag-handle cursor-move text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="w-5 h-5"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <circle cx="9" cy="5" r="1" />
                      <circle cx="9" cy="12" r="1" />
                      <circle cx="9" cy="19" r="1" />
                      <circle cx="15" cy="5" r="1" />
                      <circle cx="15" cy="12" r="1" />
                      <circle cx="15" cy="19" r="1" />
                    </svg>
                  </span>
                  <input
                    type="checkbox"
                    :value="label.title"
                    v-model="selectedTags"
                    class="w-4 h-4 text-blue-600 rounded border-slate-300 focus:ring-blue-500 dark:border-slate-600 dark:bg-slate-700"
                  />
                  <div class="flex items-center gap-2 flex-1">
                    <span
                      class="w-3 h-3 rounded-full"
                      :style="{ backgroundColor: label.color }"
                    ></span>
                    <span
                      class="text-sm font-medium text-slate-700 dark:text-slate-200"
                    >
                      {{ label.title }}
                    </span>
                  </div>
                </div>
              </template>
            </draggable>
          </div>

          <!-- Teams Settings -->
          <div v-else class="space-y-2">
            <draggable
              v-model="orderedTeams"
              item-key="id"
              handle=".drag-handle"
              class="space-y-2"
            >
              <template #item="{ element: team }">
                <div
                  class="flex items-center gap-3 p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 cursor-default"
                >
                  <span
                    class="drag-handle cursor-move text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="w-5 h-5"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <circle cx="9" cy="5" r="1" />
                      <circle cx="9" cy="12" r="1" />
                      <circle cx="9" cy="19" r="1" />
                      <circle cx="15" cy="5" r="1" />
                      <circle cx="15" cy="12" r="1" />
                      <circle cx="15" cy="19" r="1" />
                    </svg>
                  </span>
                  <input
                    type="checkbox"
                    :value="team.id"
                    v-model="selectedTeamIds"
                    class="w-4 h-4 text-blue-600 rounded border-slate-300 focus:ring-blue-500 dark:border-slate-600 dark:bg-slate-700"
                  />
                  <div class="flex items-center gap-2 flex-1">
                    <span
                      class="w-3 h-3 rounded-full"
                      :class="team.id === 0 ? 'bg-slate-400' : 'bg-slate-500'"
                    ></span>
                    <span
                      class="text-sm font-medium"
                      :class="
                        team.id === 0
                          ? 'text-slate-500 dark:text-slate-400'
                          : 'text-slate-700 dark:text-slate-200'
                      "
                    >
                      {{
                        team.id === 0
                          ? $t('KANBAN.UNASSIGNED') || 'Unassigned'
                          : team.name
                      }}
                    </span>
                  </div>
                </div>
              </template>
            </draggable>
          </div>
        </div>

        <div
          class="flex items-center justify-end gap-2 px-6 py-4 border-t border-slate-100 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/50"
        >
          <Button variant="ghost" @click="showSettingsModal = false">
            {{ $t('COMMON.CANCEL') }}
          </Button>
          <Button variant="primary" @click="saveSettings">
            {{ $t('KANBAN.UPDATE') || 'Update' }}
          </Button>
        </div>
      </div>
    </Modal>

    <Modal
      v-if="showPreviewModal"
      :show="showPreviewModal"
      :show-close-button="false"
      @close="closePreview"
      modal-type="right-aligned"
      class="w-full h-full kanban-preview-modal"
    >
      <div class="flex flex-col h-full">
        <div
          class="flex items-center justify-between px-4 py-3 border-b border-slate-100 dark:border-slate-800 bg-white dark:bg-slate-900"
        >
          <div class="flex items-center gap-2">
            <Button
              variant="ghost"
              size="sm"
              icon="i-lucide-x"
              @click="closePreview"
            />
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
            >
              #{{ currentConversation?.id }}
            </span>
          </div>
          <Button
            variant="outline"
            size="sm"
            icon="i-lucide-external-link"
            @click="navigateToConversation"
          >
            {{ $t('KANBAN.OPEN_IN_CONVERSATION') || 'Open Conversation' }}
          </Button>
        </div>
        <iframe
          :src="previewConversationUrl"
          class="flex-1 w-full border-0"
          allow="microphone"
        />
      </div>
    </Modal>
  </div>
</template>

<style lang="scss">
.kanban-preview-modal {
  .modal-container {
    @apply w-[60rem] !important;
    max-width: 90vw;
  }
}
</style>

<script setup>
import { ref, onMounted, computed, watch } from 'vue';
import { useRouter } from 'vue-router';
import KanbanAPI from 'dashboard/api/kanban';
import LabelsAPI from 'dashboard/api/labels';
import TeamsAPI from 'dashboard/api/teams';
import ConversationCard from 'dashboard/components/widgets/conversation/ConversationCard.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useI18n } from 'vue-i18n';
import draggable from 'vuedraggable';
import { useStore } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';

const KANBAN_SCROLL_THRESHOLD = 80;

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const isLoading = ref(true);
const conversations = ref({});
const columnCounts = ref({});
const columnPages = ref({});
const loadingMoreColumns = ref({});
const labels = ref([]);
const teams = ref([]);
const activeTab = ref('labels');

const showSettingsModal = ref(false);
const showPreviewModal = ref(false);
const selectedTags = ref([]);
const selectedTeamIds = ref([]);
const orderedLabels = ref([]);
const orderedTeams = ref([]);
const previewConversationUrl = ref('');
const currentConversation = ref(null);

const uiSettings = computed(() => store.getters.getUISettings || {});
const accountId = computed(() => store.getters.getCurrentAccountId);

const statuses = computed(() => {
  if (activeTab.value === 'teams') {
    const savedTeamOrder = uiSettings.value.kanban_team_order;
    const savedTeamIds = uiSettings.value.kanban_team_columns;

    // Create unassigned team object
    const unassignedTeam = {
      id: 0,
      name: t('KANBAN.UNASSIGNED') || 'Unassigned',
    };

    // Combine real teams with unassigned
    let allTeams = [unassignedTeam, ...teams.value];

    // Filter by selected teams if saved
    if (savedTeamIds && savedTeamIds.length > 0) {
      allTeams = allTeams.filter(team => savedTeamIds.includes(team.id));
    }

    // Order teams if saved order exists
    if (savedTeamOrder && savedTeamOrder.length > 0) {
      allTeams = [...allTeams].sort((a, b) => {
        const indexA = savedTeamOrder.indexOf(a.id);
        const indexB = savedTeamOrder.indexOf(b.id);
        if (indexA === -1) return 1;
        if (indexB === -1) return -1;
        return indexA - indexB;
      });
    }

    return allTeams.map(team => ({
      key: team.id === 0 ? 'Unassigned' : team.name,
      label: team.name,
      id: team.id,
      color: team.id === 0 ? '#94a3b8' : '#64748b',
    }));
  }

  const savedColumns = uiSettings.value.kanban_columns;
  const savedOrder = uiSettings.value.kanban_column_order;

  let visibleLabels = labels.value;

  if (savedColumns && savedColumns.length > 0) {
    visibleLabels = labels.value.filter(l => savedColumns.includes(l.title));
  }

  // Order labels if saved order exists
  if (savedOrder && savedOrder.length > 0) {
    visibleLabels = [...visibleLabels].sort((a, b) => {
      const indexA = savedOrder.indexOf(a.title);
      const indexB = savedOrder.indexOf(b.title);
      if (indexA === -1) return 1;
      if (indexB === -1) return -1;
      return indexA - indexB;
    });
  }

  return visibleLabels.map(label => ({
    key: label.title,
    label: label.title,
    color: label.color,
  }));
});

const selectedKanbanParams = computed(() => {
  if (activeTab.value === 'teams') {
    const savedTeamIds = uiSettings.value.kanban_team_columns;
    const teamIds =
      savedTeamIds && savedTeamIds.length > 0
        ? savedTeamIds.map(Number)
        : [0, ...teams.value.map(team => team.id)];

    return {
      group_by: 'team',
      team_ids: teamIds,
    };
  }

  const savedColumns = uiSettings.value.kanban_columns;
  const selectedLabels =
    savedColumns && savedColumns.length > 0
      ? savedColumns
      : labels.value.map(label => label.title);

  return {
    group_by: 'label',
    labels: selectedLabels,
  };
});

const switchTab = async tab => {
  activeTab.value = tab;
  if (tab === 'teams' && !teams.value.length) {
    await fetchTeams();
  }
  await fetchKanbanData();
};

const openSettings = () => {
  if (activeTab.value === 'labels') {
    const savedColumns = uiSettings.value.kanban_columns;
    const savedOrder = uiSettings.value.kanban_column_order;

    // Set up ordered labels based on saved order
    if (savedOrder && savedOrder.length > 0) {
      orderedLabels.value = [...labels.value].sort((a, b) => {
        const indexA = savedOrder.indexOf(a.title);
        const indexB = savedOrder.indexOf(b.title);
        if (indexA === -1) return 1;
        if (indexB === -1) return -1;
        return indexA - indexB;
      });
    } else {
      orderedLabels.value = [...labels.value];
    }

    if (savedColumns && savedColumns.length > 0) {
      selectedTags.value = [...savedColumns];
    } else {
      selectedTags.value = labels.value.map(l => l.title);
    }
  } else {
    const savedTeamIds = uiSettings.value.kanban_team_columns;
    const savedTeamOrder = uiSettings.value.kanban_team_order;

    // Create unassigned team object
    const unassignedTeam = {
      id: 0,
      name: t('KANBAN.UNASSIGNED') || 'Unassigned',
    };

    // Combine real teams with unassigned
    const allTeams = [unassignedTeam, ...teams.value];

    // Set up ordered teams based on saved order
    if (savedTeamOrder && savedTeamOrder.length > 0) {
      orderedTeams.value = [...allTeams].sort((a, b) => {
        const indexA = savedTeamOrder.indexOf(a.id);
        const indexB = savedTeamOrder.indexOf(b.id);
        if (indexA === -1) return 1;
        if (indexB === -1) return -1;
        return indexA - indexB;
      });
    } else {
      orderedTeams.value = [...allTeams];
    }

    if (savedTeamIds && savedTeamIds.length > 0) {
      selectedTeamIds.value = [...savedTeamIds];
    } else {
      selectedTeamIds.value = allTeams.map(t => t.id);
    }
  }
  showSettingsModal.value = true;
};

const openPreview = conversation => {
  currentConversation.value = conversation;
  const url = frontendURL(
    `accounts/${accountId.value}/conversations/${conversation.id}`
  );
  previewConversationUrl.value = `${url}?is_popout=true`;
  showPreviewModal.value = true;
};

const closePreview = () => {
  showPreviewModal.value = false;
  previewConversationUrl.value = '';
  currentConversation.value = null;
};

const navigateToConversation = () => {
  if (currentConversation.value) {
    router.push({
      name: 'inbox_conversation',
      params: { conversation_id: currentConversation.value.id },
    });
    closePreview();
  }
};

const buildColumnPageState = statusesList => {
  return statusesList.reduce((accumulator, status) => {
    accumulator[status.key] = 1;
    return accumulator;
  }, {});
};

const getColumnCount = status => {
  return (
    columnCounts.value[status.key] ??
    conversations.value[status.key]?.length ??
    0
  );
};

const isColumnLoadingMore = statusKey => {
  return Boolean(loadingMoreColumns.value[statusKey]);
};

const hasMoreConversations = statusKey => {
  const loadedConversations = conversations.value[statusKey]?.length || 0;
  const totalConversations = columnCounts.value[statusKey] || 0;

  return loadedConversations < totalConversations;
};

const getColumnParams = status => {
  if (activeTab.value === 'teams') {
    return {
      group_by: 'team',
      team_ids: [status.id],
    };
  }

  return {
    group_by: 'label',
    labels: [status.label],
  };
};

const registerContacts = data => {
  const contacts = Object.values(data)
    .flat()
    .map(conversation => conversation.meta?.sender)
    .filter(Boolean);

  contacts.forEach(contact => {
    store.commit('contacts/SET_CONTACT_ITEM', contact);
  });
};

const onColumnScroll = async (event, status) => {
  const columnElement = event.target;
  const reachedBottom =
    columnElement.scrollTop + columnElement.clientHeight >=
    columnElement.scrollHeight - KANBAN_SCROLL_THRESHOLD;

  if (!reachedBottom || isLoading.value || isColumnLoadingMore(status.key)) {
    return;
  }

  if (!hasMoreConversations(status.key)) {
    return;
  }

  loadingMoreColumns.value = {
    ...loadingMoreColumns.value,
    [status.key]: true,
  };

  try {
    const nextPage = (columnPages.value[status.key] || 1) + 1;
    const response = await KanbanAPI.get({
      ...getColumnParams(status),
      page: nextPage,
    });
    const data = response.data?.data || {};
    const nextConversations = data[status.key] || [];

    registerContacts(data);

    conversations.value = {
      ...conversations.value,
      [status.key]: [
        ...(conversations.value[status.key] || []),
        ...nextConversations,
      ],
    };
    columnPages.value = {
      ...columnPages.value,
      [status.key]: nextPage,
    };
  } catch (error) {
    console.error('Error loading more kanban conversations:', error);
  } finally {
    loadingMoreColumns.value = {
      ...loadingMoreColumns.value,
      [status.key]: false,
    };
  }
};

const saveSettings = async () => {
  try {
    if (activeTab.value === 'labels') {
      await store.dispatch('updateUISettings', {
        uiSettings: {
          kanban_columns: selectedTags.value,
          kanban_column_order: orderedLabels.value.map(l => l.title),
        },
      });
    } else {
      await store.dispatch('updateUISettings', {
        uiSettings: {
          kanban_team_columns: selectedTeamIds.value,
          kanban_team_order: orderedTeams.value.map(t => t.id),
        },
      });
    }
    await fetchKanbanData();
    showSettingsModal.value = false;
  } catch (error) {
    console.error('Error saving settings:', error);
  }
};

const fetchLabels = async () => {
  try {
    const response = await LabelsAPI.get();
    labels.value = response.data.payload;
  } catch (error) {
    console.error('Error fetching labels:', error);
  }
};

const fetchTeams = async () => {
  try {
    const response = await TeamsAPI.get();
    teams.value = response.data;
  } catch (error) {
    console.error('Error fetching teams:', error);
  }
};

const fetchKanbanData = async () => {
  try {
    isLoading.value = true;
    const response = await KanbanAPI.get(selectedKanbanParams.value);
    const data = response.data?.data || {};
    const counts = response.data?.meta?.column_counts || {};

    registerContacts(data);

    conversations.value = statuses.value.reduce(
      (accumulator, status) => ({
        ...accumulator,
        [status.key]: data[status.key] || [],
      }),
      {}
    );
    columnCounts.value = statuses.value.reduce(
      (accumulator, status) => ({
        ...accumulator,
        [status.key]: counts[status.key] ?? data[status.key]?.length ?? 0,
      }),
      {}
    );
    columnPages.value = buildColumnPageState(statuses.value);
    loadingMoreColumns.value = {};
  } catch (error) {
    console.error('Error fetching kanban data:', error);
    conversations.value = {};
    columnCounts.value = {};
    columnPages.value = {};
    loadingMoreColumns.value = {};
  } finally {
    isLoading.value = false;
  }
};

onMounted(async () => {
  await fetchLabels();
  await fetchKanbanData();
});

const onDragChange = async (event, newStatus) => {
  if (event.removed) {
    columnCounts.value = {
      ...columnCounts.value,
      [newStatus]: Math.max((columnCounts.value[newStatus] || 1) - 1, 0),
    };
    return;
  }

  if (event.added) {
    const conversation = event.added.element;

    columnCounts.value = {
      ...columnCounts.value,
      [newStatus]: (columnCounts.value[newStatus] || 0) + 1,
    };

    if (activeTab.value === 'teams') {
      const team = teams.value.find(t => t.name === newStatus);
      const teamId = team ? team.id : 0;

      try {
        await store.dispatch('assignTeam', {
          conversationId: conversation.id,
          teamId: teamId,
        });
      } catch (error) {
        console.error('Error updating team:', error);
        fetchKanbanData();
      }
      return;
    }

    const newLabel = newStatus;

    const kanbanLabelTitles = labels.value.map(l => l.title);
    const currentLabels = conversation.labels || [];

    // Remove other kanban labels (enforcing single status column behavior)
    const otherKanbanLabels = kanbanLabelTitles.filter(t => t !== newLabel);
    const newLabelsList = currentLabels.filter(
      l => !otherKanbanLabels.includes(l)
    );

    if (!newLabelsList.includes(newLabel)) {
      newLabelsList.push(newLabel);
    }

    // Update local object
    conversation.labels = newLabelsList;

    try {
      await store.dispatch('conversationLabels/update', {
        conversationId: conversation.id,
        labels: newLabelsList,
      });
    } catch (error) {
      console.error('Error updating labels:', error);
      fetchKanbanData();
    }
  }
};
</script>
