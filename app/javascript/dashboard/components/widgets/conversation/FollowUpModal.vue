<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  conversationId: {
    type: [Number, String],
    required: true,
  },
  defaultContent: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close', 'created']);

const { t } = useI18n();
const store = useStore();

const mode = ref('remind_me');
const dueAt = ref('');
const note = ref('');
const content = ref('');
const selectedWorkflowId = ref(null);
const cancelOnIncoming = ref(true);

const localShow = computed({
  get: () => props.show,
  set: value => {
    if (!value) emit('close');
  },
});

const uiFlags = useMapGetter('followUps/getUIFlags');
const getFollowUps = useMapGetter('followUps/getFollowUpsByConversation');
const workflows = useMapGetter('followUps/getWorkflows');

const isCreating = computed(() => uiFlags.value.isCreating);
const isFetching = computed(() => uiFlags.value.isFetching);
const runs = computed(() => getFollowUps.value(props.conversationId));
const activeRuns = computed(() =>
  runs.value.filter(run => run.status === 'active')
);
const historyRuns = computed(() =>
  runs.value.filter(run => run.status !== 'active')
);
const manualWorkflows = computed(() =>
  (workflows.value || []).filter(
    workflow =>
      workflow.active && ['manual', 'both'].includes(workflow.trigger_mode)
  )
);

const minDateTime = computed(() => {
  const date = new Date();
  date.setMinutes(date.getMinutes() + 1);
  date.setSeconds(0, 0);
  const offset = date.getTimezoneOffset();
  const local = new Date(date.getTime() - offset * 60_000);
  return local.toISOString().slice(0, 16);
});

const canSubmit = computed(() => {
  if (isCreating.value) return false;
  if (mode.value === 'workflow') return Boolean(selectedWorkflowId.value);
  if (!dueAt.value) return false;
  if (mode.value === 'message_if_no_reply')
    return Boolean(content.value.trim());
  return true;
});

const formatDueAt = timestamp => {
  if (!timestamp) return '';
  return new Date(timestamp * 1000).toLocaleString();
};

watch(
  () => props.show,
  visible => {
    if (!visible) return;
    dueAt.value = minDateTime.value;
    note.value = '';
    content.value = props.defaultContent || '';
    mode.value = 'remind_me';
    selectedWorkflowId.value = null;
    cancelOnIncoming.value = true;
    store.dispatch('followUps/getForConversation', {
      conversationId: props.conversationId,
    });
    store.dispatch('followUps/getWorkflows');
  }
);

const onClose = () => emit('close');

const buildPayload = () => {
  if (mode.value === 'workflow') {
    return {
      run_type: 'workflow',
      follow_up_workflow_id: selectedWorkflowId.value,
      cancel_on_incoming: cancelOnIncoming.value,
    };
  }

  if (mode.value === 'message_if_no_reply') {
    return {
      run_type: 'message_if_no_reply',
      due_at: new Date(dueAt.value).toISOString(),
      content: content.value.trim(),
      cancel_on_incoming: true,
    };
  }

  return {
    run_type: 'remind_me',
    due_at: new Date(dueAt.value).toISOString(),
    note: note.value.trim() || content.value.trim(),
    cancel_on_incoming: false,
  };
};

const onConfirm = async () => {
  if (!canSubmit.value) return;
  try {
    await store.dispatch('followUps/create', {
      conversationId: props.conversationId,
      payload: buildPayload(),
    });
    useAlert(t('FOLLOW_UPS.CREATE_SUCCESS'));
    emit('created');
    onClose();
  } catch (error) {
    useAlert(t('FOLLOW_UPS.CREATE_ERROR'));
  }
};

const onCancel = async id => {
  try {
    await store.dispatch('followUps/cancel', {
      conversationId: props.conversationId,
      id,
    });
    useAlert(t('FOLLOW_UPS.CANCEL_SUCCESS'));
  } catch (error) {
    useAlert(t('FOLLOW_UPS.CANCEL_ERROR'));
  }
};

const onRetry = async id => {
  try {
    await store.dispatch('followUps/retry', {
      conversationId: props.conversationId,
      id,
    });
    useAlert(t('FOLLOW_UPS.HISTORY_RETRY_SUCCESS'));
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('FOLLOW_UPS.HISTORY_RETRY_ERROR')
    );
  }
};

const formatTimestamp = value => {
  if (!value) return '—';
  const date =
    typeof value === 'number' ? new Date(value * 1000) : new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleString();
};
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onClose" size="medium">
    <woot-modal-header
      :header-title="$t('FOLLOW_UPS.MODAL_TITLE')"
      :header-content="$t('FOLLOW_UPS.MODAL_SUBTITLE')"
    />
    <div class="flex flex-col gap-4 px-4 pb-6 sm:px-8">
      <div class="flex flex-wrap gap-2">
        <NextButton
          sm
          :solid="mode === 'remind_me'"
          :faded="mode !== 'remind_me'"
          :slate="mode !== 'remind_me'"
          :label="$t('FOLLOW_UPS.MODES.REMIND_ME')"
          @click="mode = 'remind_me'"
        />
        <NextButton
          sm
          :solid="mode === 'message_if_no_reply'"
          :faded="mode !== 'message_if_no_reply'"
          :slate="mode !== 'message_if_no_reply'"
          :label="$t('FOLLOW_UPS.MODES.MESSAGE_IF_NO_REPLY')"
          @click="mode = 'message_if_no_reply'"
        />
        <NextButton
          sm
          :solid="mode === 'workflow'"
          :faded="mode !== 'workflow'"
          :slate="mode !== 'workflow'"
          :label="$t('FOLLOW_UPS.MODES.WORKFLOW')"
          @click="mode = 'workflow'"
        />
      </div>

      <div v-if="mode !== 'workflow'" class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('FOLLOW_UPS.DUE_AT') }}
        </label>
        <input
          v-model="dueAt"
          type="datetime-local"
          :min="minDateTime"
          class="w-full px-3 py-2 text-sm rounded-lg reset-base bg-n-background text-n-slate-12 outline outline-1 outline-n-weak focus:outline-n-brand"
        />
      </div>

      <div v-if="mode === 'remind_me'" class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('FOLLOW_UPS.NOTE_LABEL') }}
        </label>
        <textarea
          v-model="note"
          rows="3"
          class="w-full px-3 py-2 text-sm rounded-lg reset-base bg-n-background text-n-slate-12 outline outline-1 outline-n-weak focus:outline-n-brand"
          :placeholder="$t('FOLLOW_UPS.NOTE_PLACEHOLDER')"
        />
      </div>

      <div v-if="mode === 'message_if_no_reply'" class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('FOLLOW_UPS.MESSAGE_LABEL') }}
        </label>
        <textarea
          v-model="content"
          rows="4"
          class="w-full px-3 py-2 text-sm rounded-lg reset-base bg-n-background text-n-slate-12 outline outline-1 outline-n-weak focus:outline-n-brand"
          :placeholder="$t('FOLLOW_UPS.MESSAGE_PLACEHOLDER')"
        />
        <p class="mb-0 text-xs text-n-slate-11">
          {{ $t('FOLLOW_UPS.CANCEL_ON_REPLY_HINT') }}
        </p>
      </div>

      <div v-if="mode === 'workflow'" class="flex flex-col gap-3">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('FOLLOW_UPS.WORKFLOW_LABEL') }}
        </label>
        <select
          v-model="selectedWorkflowId"
          class="w-full px-3 py-2 text-sm rounded-lg reset-base bg-n-background text-n-slate-12 outline outline-1 outline-n-weak"
        >
          <option :value="null" disabled>
            {{ $t('FOLLOW_UPS.WORKFLOW_PLACEHOLDER') }}
          </option>
          <option
            v-for="workflow in manualWorkflows"
            :key="workflow.id"
            :value="workflow.id"
          >
            {{
              workflow.preset_key
                ? $t(`FOLLOW_UPS.PRESETS.${workflow.preset_key}`)
                : workflow.name
            }}
          </option>
        </select>
        <label class="flex items-center gap-2 text-sm text-n-slate-12">
          <input v-model="cancelOnIncoming" type="checkbox" />
          {{ $t('FOLLOW_UPS.CANCEL_ON_REPLY') }}
        </label>
      </div>

      <div class="flex justify-end gap-2">
        <NextButton
          faded
          slate
          :label="$t('FOLLOW_UPS.CANCEL')"
          @click="onClose"
        />
        <NextButton
          solid
          blue
          icon="i-lucide-corner-up-right"
          :disabled="!canSubmit"
          :is-loading="isCreating"
          :label="$t('FOLLOW_UPS.CONFIRM')"
          @click="onConfirm"
        />
      </div>

      <div class="pt-2 border-t border-n-weak">
        <h4 class="mb-2 text-sm font-medium text-n-slate-12">
          {{ $t('FOLLOW_UPS.ACTIVE_TITLE') }}
        </h4>
        <div v-if="isFetching" class="flex justify-center py-4">
          <Spinner />
        </div>
        <p v-else-if="!activeRuns.length" class="mb-0 text-sm text-n-slate-11">
          {{ $t('FOLLOW_UPS.EMPTY') }}
        </p>
        <ul v-else class="flex flex-col gap-2 m-0 list-none">
          <li
            v-for="run in activeRuns"
            :key="run.id"
            class="flex items-start justify-between gap-2 p-3 rounded-lg outline outline-1 outline-n-weak"
          >
            <div class="flex flex-col gap-1 min-w-0">
              <span class="text-xs font-medium text-n-slate-11">
                {{ formatDueAt(run.next_due_at) }}
              </span>
              <p class="mb-0 text-sm text-n-slate-12">
                {{
                  run.workflow?.preset_key
                    ? $t(`FOLLOW_UPS.PRESETS.${run.workflow.preset_key}`)
                    : run.workflow?.name ||
                      $t(`FOLLOW_UPS.RUN_TYPES.${run.run_type.toUpperCase()}`)
                }}
              </p>
            </div>
            <NextButton
              xs
              ghost
              ruby
              icon="i-lucide-trash-2"
              :title="$t('FOLLOW_UPS.CANCEL_RUN')"
              @click="onCancel(run.id)"
            />
          </li>
        </ul>
      </div>

      <div class="pt-2 border-t border-n-weak">
        <h4 class="mb-2 text-sm font-medium text-n-slate-12">
          {{ $t('FOLLOW_UPS.HISTORY_TITLE') }}
        </h4>
        <p
          v-if="!isFetching && !historyRuns.length"
          class="mb-0 text-sm text-n-slate-11"
        >
          {{ $t('FOLLOW_UPS.HISTORY_EMPTY') }}
        </p>
        <ul v-else class="flex flex-col gap-2 m-0 list-none">
          <li
            v-for="run in historyRuns"
            :key="`history-${run.id}`"
            class="flex flex-col gap-2 p-3 rounded-lg outline outline-1 outline-n-weak"
          >
            <div class="flex items-start justify-between gap-2">
              <div class="flex flex-col gap-1 min-w-0">
                <span class="text-xs font-medium capitalize text-n-slate-11">
                  {{ $t(`FOLLOW_UPS.HISTORY_STATUS.${run.status}`) }}
                  ·
                  {{ formatTimestamp(run.updated_at) }}
                </span>
                <p class="mb-0 text-sm text-n-slate-12">
                  {{
                    run.workflow?.preset_key
                      ? $t(`FOLLOW_UPS.PRESETS.${run.workflow.preset_key}`)
                      : run.workflow?.name ||
                        $t(`FOLLOW_UPS.RUN_TYPES.${run.run_type.toUpperCase()}`)
                  }}
                </p>
                <p
                  v-if="run.error || run.cancel_reason"
                  class="mb-0 text-xs text-n-ruby-11"
                >
                  {{ run.error || run.cancel_reason }}
                </p>
              </div>
              <NextButton
                v-if="run.status === 'failed'"
                xs
                solid
                blue
                :label="$t('FOLLOW_UPS.HISTORY_RETRY')"
                @click="onRetry(run.id)"
              />
            </div>
          </li>
        </ul>
      </div>
    </div>
  </woot-modal>
</template>
