<template>
  <div class="flex flex-col h-full overflow-hidden bg-slate-50 dark:bg-slate-900">
    <div class="flex items-center justify-between px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-200 dark:border-slate-800">
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
            :class="activeTab === tab ? 'bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 shadow-sm' : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'"
          >
            {{ $t(`KANBAN.TABS.${tab.toUpperCase()}`) || tab }}
          </button>
        </div>
      </div>
      <Button
        v-if="activeTab === 'labels'"
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
        <div class="flex items-center justify-between p-3 border-b border-slate-200 dark:border-slate-700">
          <div class="flex items-center gap-2">
            <span class="font-medium text-slate-700 dark:text-slate-200 capitalize">
              {{ status.label }}
            </span>
            <span class="px-2 py-0.5 text-xs font-medium bg-slate-200 dark:bg-slate-700 rounded-full text-slate-600 dark:text-slate-300">
              {{ (conversations[status.key] || []).length }}
            </span>
          </div>
        </div>

        <div class="flex-1 p-2 overflow-y-auto space-y-2">
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
        <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 dark:border-slate-800">
          <h3 class="text-base font-medium text-slate-800 dark:text-slate-100">
            {{ $t('KANBAN.SETTINGS_TITLE') || 'Configure Columns' }}
          </h3>
        </div>

        <div class="p-6 overflow-y-auto max-h-[60vh]">
          <div class="space-y-3">
            <label
              v-for="label in labels"
              :key="label.title"
              class="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer border border-transparent hover:border-slate-100 dark:hover:border-slate-700 transition-colors"
            >
              <input
                type="checkbox"
                :value="label.title"
                v-model="selectedTags"
                class="w-4 h-4 text-blue-600 rounded border-slate-300 focus:ring-blue-500 dark:border-slate-600 dark:bg-slate-700"
              >
              <div class="flex items-center gap-2">
                <span
                  class="w-3 h-3 rounded-full"
                  :style="{ backgroundColor: label.color }"
                ></span>
                <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
                  {{ label.title }}
                </span>
              </div>
            </label>
          </div>
        </div>

        <div class="flex items-center justify-end gap-2 px-6 py-4 border-t border-slate-100 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/50">
          <Button
            variant="ghost"
            @click="showSettingsModal = false"
          >
            {{ $t('COMMON.CANCEL') }}
          </Button>
          <Button
            variant="primary"
            @click="saveSettings"
          >
            {{ $t('KANBAN.UPDATE') || 'Update' }}
          </Button>
        </div>
      </div>
    </Modal>

    <Modal
      v-if="showPreviewModal"
      :show="showPreviewModal"
      @close="closePreview"
      modal-type="right-aligned"
      class="w-full h-full kanban-preview-modal"
    >
      <iframe
        :src="previewConversationUrl"
        class="w-full h-full border-0"
        allow="microphone"
      />
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

const { t } = useI18n();
const store = useStore();

const isLoading = ref(true);
const conversations = ref({});
const labels = ref([]);
const teams = ref([]);
const activeTab = ref('labels');

const showSettingsModal = ref(false);
const showPreviewModal = ref(false);
const selectedTags = ref([]);
const previewConversationUrl = ref('');

const uiSettings = computed(() => store.getters.getUISettings || {});
const accountId = computed(() => store.getters.getCurrentAccountId);

const statuses = computed(() => {
  if (activeTab.value === 'teams') {
    const teamColumns = teams.value.map(team => ({
      key: team.name,
      label: team.name,
      id: team.id,
      color: '#64748b',
    }));

    teamColumns.push({
      key: 'Unassigned',
      label: t('KANBAN.UNASSIGNED') || 'Unassigned',
      id: 0,
      color: '#94a3b8',
    });

    return teamColumns;
  }

  const savedColumns = uiSettings.value.kanban_columns;
  let visibleLabels = labels.value;

  if (savedColumns) {
    visibleLabels = labels.value.filter(l => savedColumns.includes(l.title));
  }

  return visibleLabels.map(label => ({
    key: label.title,
    label: label.title,
    color: label.color,
  }));
});

const switchTab = async (tab) => {
  activeTab.value = tab;
  await fetchKanbanData();
};

const openSettings = () => {
  const savedColumns = uiSettings.value.kanban_columns;
  if (savedColumns) {
    selectedTags.value = [...savedColumns];
  } else {
    selectedTags.value = labels.value.map(l => l.title);
  }
  showSettingsModal.value = true;
};

const openPreview = (conversation) => {
  const url = frontendURL(`accounts/${accountId.value}/conversations/${conversation.id}`);
  previewConversationUrl.value = `${url}?is_popout=true`;
  showPreviewModal.value = true;
};

const closePreview = () => {
  showPreviewModal.value = false;
  previewConversationUrl.value = '';
};

const saveSettings = async () => {
  try {
    await store.dispatch('updateUISettings', {
      uiSettings: {
        kanban_columns: selectedTags.value
      }
    });
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
    const params = { group_by: activeTab.value === 'teams' ? 'team' : 'label' };
    const response = await KanbanAPI.get(params);
    conversations.value = response.data.data;
  } catch (error) {
    console.error('Error fetching kanban data:', error);
  } finally {
    isLoading.value = false;
  }
};

onMounted(async () => {
  await Promise.all([fetchLabels(), fetchTeams()]);
  fetchKanbanData();
});

const onDragChange = async (event, newStatus) => {
  if (event.added) {
    const conversation = event.added.element;

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
    const newLabelsList = currentLabels.filter(l => !otherKanbanLabels.includes(l));

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
