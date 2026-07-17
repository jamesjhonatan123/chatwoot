<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { useAccount } from 'dashboard/composables/useAccount';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const STATUS_FILTERS = ['all', 'active', 'completed', 'failed', 'cancelled'];

const { t } = useI18n();
const store = useStore();
const { accountId } = useAccount();

const statusFilter = ref('all');
const expandedId = ref(null);

const uiFlags = useMapGetter('followUps/getUIFlags');
const historyRecords = useMapGetter('followUps/getHistoryFollowUps');

const isFetching = computed(() => uiFlags.value.isFetchingHistory);
const isRetrying = computed(() => uiFlags.value.isRetrying);

const fetchHistory = () => {
  const params = {};
  if (statusFilter.value !== 'all') {
    params.status = statusFilter.value;
  }
  store.dispatch('followUps/getHistory', params);
};

onMounted(fetchHistory);
watch(statusFilter, fetchHistory);

const formatTime = value => {
  if (!value) return '—';
  const date =
    typeof value === 'number' ? new Date(value * 1000) : new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleString();
};

const workflowName = run => {
  if (run.workflow?.preset_key) {
    return t(`FOLLOW_UPS.PRESETS.${run.workflow.preset_key}`);
  }
  return (
    run.workflow?.name ||
    t(`FOLLOW_UPS.RUN_TYPES.${run.run_type.toUpperCase()}`)
  );
};

const statusClass = status => {
  const map = {
    active: 'bg-n-brand/10 text-n-blue-11',
    completed: 'bg-n-teal-3 text-n-teal-11',
    failed: 'bg-n-ruby-3 text-n-ruby-11',
    cancelled: 'bg-n-slate-3 text-n-slate-11',
  };
  return map[status] || 'bg-n-slate-3 text-n-slate-11';
};

const stepStatusClass = status => {
  const map = {
    scheduled: 'text-n-slate-11',
    running: 'text-n-blue-11',
    done: 'text-n-teal-11',
    skipped: 'text-n-amber-11',
    failed: 'text-n-ruby-11',
    cancelled: 'text-n-slate-11',
  };
  return map[status] || 'text-n-slate-11';
};

const toggleExpand = id => {
  expandedId.value = expandedId.value === id ? null : id;
};

const conversationUrl = run =>
  frontendURL(
    `accounts/${accountId.value}/conversations/${run.conversation?.display_id}`
  );

const onRetry = async run => {
  try {
    await store.dispatch('followUps/retry', { id: run.id });
    useAlert(t('FOLLOW_UPS.HISTORY_RETRY_SUCCESS'));
    fetchHistory();
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('FOLLOW_UPS.HISTORY_RETRY_ERROR')
    );
  }
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <h3 class="mb-0 text-base font-medium text-n-slate-12">
        {{ $t('FOLLOW_UPS.HISTORY_TITLE') }}
      </h3>
      <div class="flex flex-wrap gap-2">
        <NextButton
          v-for="status in STATUS_FILTERS"
          :key="status"
          xs
          :solid="statusFilter === status"
          :faded="statusFilter !== status"
          :slate="statusFilter !== status"
          :label="$t(`FOLLOW_UPS.HISTORY_FILTERS.${status}`)"
          @click="statusFilter = status"
        />
      </div>
    </div>

    <div v-if="isFetching" class="flex justify-center py-6">
      <Spinner />
    </div>

    <p v-else-if="!historyRecords.length" class="mb-0 text-sm text-n-slate-11">
      {{ $t('FOLLOW_UPS.HISTORY_EMPTY') }}
    </p>

    <ul v-else class="flex flex-col gap-3 m-0 list-none">
      <li
        v-for="run in historyRecords"
        :key="run.id"
        class="flex flex-col gap-3 p-4 rounded-lg outline outline-1 outline-n-weak"
      >
        <div
          class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between"
        >
          <div class="min-w-0 flex flex-col gap-1">
            <div class="flex flex-wrap items-center gap-2">
              <span
                class="px-2 py-0.5 text-xs rounded capitalize"
                :class="statusClass(run.status)"
              >
                {{ $t(`FOLLOW_UPS.HISTORY_STATUS.${run.status}`) }}
              </span>
              <span class="text-sm font-medium text-n-slate-12">
                {{ workflowName(run) }}
              </span>
            </div>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ $t('FOLLOW_UPS.HISTORY_UPDATED_AT') }}:
              {{ formatTime(run.updated_at) }}
              ·
              {{ $t('FOLLOW_UPS.HISTORY_CREATED_AT') }}:
              {{ formatTime(run.created_at) }}
            </p>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ $t('FOLLOW_UPS.HISTORY_CONVERSATION') }}:
              <a
                :href="conversationUrl(run)"
                class="text-n-blue-11 hover:underline"
              >
                #{{ run.conversation?.display_id }}
              </a>
              · {{ run.user?.available_name || run.user?.name }}
            </p>
            <p
              v-if="run.error || run.cancel_reason"
              class="mb-0 text-xs text-n-ruby-11"
            >
              {{ run.error || run.cancel_reason }}
            </p>
          </div>

          <div class="flex flex-wrap gap-2">
            <NextButton
              xs
              faded
              slate
              :label="
                expandedId === run.id
                  ? $t('FOLLOW_UPS.HISTORY_HIDE_STEPS')
                  : $t('FOLLOW_UPS.HISTORY_SHOW_STEPS')
              "
              @click="toggleExpand(run.id)"
            />
            <NextButton
              v-if="run.status === 'failed'"
              xs
              solid
              blue
              :is-loading="isRetrying"
              :label="$t('FOLLOW_UPS.HISTORY_RETRY')"
              @click="onRetry(run)"
            />
          </div>
        </div>

        <div
          v-if="expandedId === run.id"
          class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-black2"
        >
          <div
            v-for="step in run.steps || []"
            :key="step.id"
            class="flex flex-col gap-1 pb-2 border-b border-n-weak last:border-0 last:pb-0"
          >
            <div class="flex flex-wrap items-center justify-between gap-2">
              <span class="text-sm font-medium text-n-slate-12">
                {{ $t('FOLLOW_UPS.HISTORY_STEP') }} #{{ step.position + 1 }}
              </span>
              <span
                class="text-xs capitalize"
                :class="stepStatusClass(step.status)"
              >
                {{ $t(`FOLLOW_UPS.HISTORY_STEP_STATUS.${step.status}`) }}
              </span>
            </div>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ $t('FOLLOW_UPS.HISTORY_DUE_AT') }}:
              {{ formatTime(step.due_at) }}
            </p>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ $t('FOLLOW_UPS.HISTORY_STARTED_AT') }}:
              {{ formatTime(step.started_at) }}
              ·
              {{ $t('FOLLOW_UPS.HISTORY_FINISHED_AT') }}:
              {{ formatTime(step.finished_at) }}
            </p>
            <p v-if="step.error_message" class="mb-0 text-xs text-n-ruby-11">
              {{ step.error_message }}
            </p>
            <ul
              v-if="step.actions?.length"
              class="flex flex-col gap-1 m-0 list-none"
            >
              <li
                v-for="(action, index) in step.actions"
                :key="`${step.id}-${index}`"
                class="text-xs text-n-slate-11"
              >
                {{ action.action_name }}
                {{ $t('FOLLOW_UPS.HISTORY_ARROW') }}
                <span :class="stepStatusClass(action.status)">
                  {{ action.status }}
                </span>
                <span v-if="action.error" class="text-n-ruby-11">
                  {{
                    $t('FOLLOW_UPS.HISTORY_ACTION_ERROR', {
                      error: action.error,
                    })
                  }}
                </span>
              </li>
            </ul>
          </div>
        </div>
      </li>
    </ul>
  </div>
</template>
