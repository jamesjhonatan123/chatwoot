<script setup>
import { ref, computed, watch, nextTick, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useMacros } from 'dashboard/composables/useMacros';
import { useCaptain } from 'dashboard/composables/useCaptain';
import actionQueryGenerator from 'dashboard/helper/actionQueryGenerator.js';
import TasksAPI from 'dashboard/api/captain/tasks';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AutomationActionInput from 'dashboard/components/widgets/AutomationActionInput.vue';
import FollowUpSendMessageParams from './FollowUpSendMessageParams.vue';

const FOLLOW_UP_ACTION_TYPES = [
  { key: 'send_message', inputType: null },
  { key: 'add_private_note', inputType: 'textarea' },
  { key: 'notify_assignee', inputType: null },
  { key: 'add_label', inputType: 'multi_select' },
  { key: 'assign_agent', inputType: 'search_select' },
  { key: 'assign_team', inputType: 'search_select' },
  { key: 'change_status', inputType: 'search_select' },
  { key: 'resolve_conversation', inputType: null },
  { key: 'open_conversation', inputType: null },
  { key: 'change_priority', inputType: 'search_select' },
];

const emptyAction = () => ({
  action_name: 'notify_assignee',
  action_params: [],
});

const emptyStep = () => ({
  type: 'wait_then_act',
  wait: { value: 24, unit: 'hours', business_hours: false },
  conditions: [
    {
      attribute_key: 'no_incoming_since_anchor',
      filter_operator: 'equal_to',
      values: [true],
    },
  ],
  on_fail: 'abort',
  actions: [emptyAction()],
  branch: null,
});

const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { getMacroDropdownValues } = useMacros();
const { captainTasksEnabled } = useCaptain();

const workflows = useMapGetter('followUps/getWorkflows');
const uiFlags = useMapGetter('followUps/getUIFlags');

const name = ref('');
const description = ref('');
const triggerMode = ref('manual');
const active = ref(true);
const steps = ref([emptyStep()]);
const aiPrompt = ref('');
const aiDraft = ref(null);
const isGeneratingAi = ref(false);

const workflowId = computed(() => route.params.workflowId);
const isEditing = computed(() => Boolean(workflowId.value));
const isSaving = computed(() => uiFlags.value.isSavingWorkflow);

const actionTypes = computed(() =>
  FOLLOW_UP_ACTION_TYPES.map(type => ({
    ...type,
    label: t(`FOLLOW_UPS.ACTION_TYPES.${type.key}`),
  }))
);

const currentWorkflow = computed(() =>
  workflows.value.find(item => String(item.id) === String(workflowId.value))
);

const getDropdownValues = actionName => getMacroDropdownValues(actionName);

const showActionInput = action => {
  const type = actionTypes.value.find(item => item.key === action.action_name);
  return Boolean(type?.inputType);
};

const formatSendMessageAction = action => {
  const params = action.action_params;
  if (Array.isArray(params) && params.length) {
    const first = params[0];
    if (first && typeof first === 'object') {
      return { ...action, action_params: first };
    }
    return { ...action, action_params: first || '' };
  }
  if (params && typeof params === 'object') {
    return { ...action, action_params: params };
  }
  return { ...action, action_params: params || '' };
};

const formatAction = action => {
  if (action.action_name === 'send_message') {
    return formatSendMessageAction(action);
  }

  const params = Array.isArray(action.action_params)
    ? action.action_params
    : [];
  const type = actionTypes.value.find(item => item.key === action.action_name);
  const inputType = type?.inputType;

  if (!params.length) {
    return { ...action, action_params: [] };
  }

  if (inputType === 'multi_select' || inputType === 'search_select') {
    const selected = getDropdownValues(action.action_name).filter(item =>
      params.map(param => String(param)).includes(String(item.id))
    );
    return { ...action, action_params: selected };
  }

  return { ...action, action_params: [...params] };
};

const serializeSendMessageAction = action => {
  const params = action.action_params;
  if (
    params &&
    typeof params === 'object' &&
    !Array.isArray(params) &&
    params.template_params
  ) {
    return {
      action_name: 'send_message',
      action_params: [params],
    };
  }

  const content = Array.isArray(params) ? params[0] : params;
  return {
    action_name: 'send_message',
    action_params: content ? [content] : [''],
  };
};

const serializeActions = actions =>
  actions.map(action => {
    if (action.action_name === 'send_message') {
      return serializeSendMessageAction(action);
    }
    return actionQueryGenerator([action])[0];
  });

const normalizeSteps = rawSteps => {
  const list = Array.isArray(rawSteps)
    ? rawSteps
    : Object.values(rawSteps || {});
  if (!list.length) return [emptyStep()];

  return list.map(step => ({
    ...emptyStep(),
    ...step,
    wait: {
      value: step?.wait?.value ?? 24,
      unit: step?.wait?.unit || 'hours',
      business_hours: Boolean(step?.wait?.business_hours),
    },
    conditions: Array.isArray(step?.conditions) ? step.conditions : [],
    actions:
      Array.isArray(step?.actions) && step.actions.length
        ? step.actions.map(formatAction)
        : [emptyAction()],
    branch: step?.branch || null,
  }));
};

const hydrateFromWorkflow = workflow => {
  if (!workflow) return;
  name.value = workflow.name;
  description.value = workflow.description || '';
  triggerMode.value = workflow.trigger_mode;
  active.value = workflow.active;
  steps.value = normalizeSteps(workflow.steps);
};

const fetchDropdownData = () =>
  Promise.all([
    store.dispatch('agents/get'),
    store.dispatch('teams/get'),
    store.dispatch('labels/get'),
    store.dispatch('inboxes/get'),
  ]);

onMounted(() => {
  fetchDropdownData();
});

watch(
  () => [workflowId.value, workflows.value],
  async () => {
    if (!workflowId.value) return;

    await fetchDropdownData();

    if (!workflows.value.length) {
      await store.dispatch('followUps/getWorkflows');
    }

    await nextTick();
    hydrateFromWorkflow(currentWorkflow.value);
  },
  { immediate: true }
);

const addStep = () => {
  steps.value.push(emptyStep());
};

const removeStep = index => {
  steps.value.splice(index, 1);
};

const addAction = step => {
  step.actions.push(emptyAction());
};

const removeAction = (step, index) => {
  step.actions.splice(index, 1);
};

const resetAction = action => {
  if (action.action_name === 'send_message') {
    action.action_params = '';
    return;
  }
  action.action_params = [];
};

const toggleBranch = index => {
  if (steps.value[index].branch) {
    steps.value[index].branch = null;
    return;
  }
  steps.value[index].branch = {
    if: [
      {
        attribute_key: 'status',
        filter_operator: 'equal_to',
        values: ['open'],
      },
    ],
    then_goto: index + 1,
    else_goto: null,
  };
};

const onSave = async () => {
  const payload = {
    name: name.value.trim(),
    description: description.value.trim(),
    trigger_mode: triggerMode.value,
    active: active.value,
    steps: steps.value.map(step => ({
      ...step,
      actions: serializeActions(step.actions),
    })),
  };

  try {
    if (isEditing.value) {
      await store.dispatch('followUps/updateWorkflow', {
        id: workflowId.value,
        ...payload,
      });
    } else {
      await store.dispatch('followUps/createWorkflow', payload);
    }
    useAlert(t('FOLLOW_UPS.CREATE_WORKFLOW_SUCCESS'));
    router.push({ name: 'follow_ups_wrapper' });
  } catch (error) {
    useAlert(t('FOLLOW_UPS.CREATE_WORKFLOW_ERROR'));
  }
};

const generateWithAi = async () => {
  if (!aiPrompt.value.trim()) {
    useAlert(t('FOLLOW_UPS.AI_BUILDER_EMPTY'));
    return;
  }

  isGeneratingAi.value = true;
  try {
    const { data } = await TasksAPI.generateFollowUpWorkflow({
      prompt: aiPrompt.value.trim(),
      language: locale.value || 'en',
    });
    aiDraft.value = data.workflow;
    useAlert(t('FOLLOW_UPS.AI_BUILDER_SUCCESS'));
  } catch (error) {
    const message =
      error.response?.data?.error || t('FOLLOW_UPS.AI_BUILDER_ERROR');
    useAlert(message);
  } finally {
    isGeneratingAi.value = false;
  }
};

const applyAiDraft = () => {
  if (!aiDraft.value) return;
  name.value = aiDraft.value.name || name.value;
  description.value = aiDraft.value.description || '';
  triggerMode.value = aiDraft.value.trigger_mode || 'manual';
  steps.value = normalizeSteps(aiDraft.value.steps);
  aiDraft.value = null;
};

const discardAiDraft = () => {
  aiDraft.value = null;
};
</script>

<template>
  <div class="flex flex-col gap-6 max-w-3xl">
    <div
      v-if="captainTasksEnabled"
      class="flex flex-col gap-3 p-4 rounded-lg outline outline-1 outline-n-weak bg-n-alpha-1"
    >
      <div class="flex items-center gap-2">
        <span class="i-ph-sparkle-fill text-n-brand text-base" />
        <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
          {{ $t('FOLLOW_UPS.AI_BUILDER_TITLE') }}
        </h3>
      </div>
      <p class="mb-0 text-xs text-n-slate-11">
        {{ $t('FOLLOW_UPS.AI_BUILDER_HELPER') }}
      </p>
      <textarea
        v-model="aiPrompt"
        rows="3"
        class="w-full px-3 py-2 text-sm rounded-lg reset-base bg-n-background text-n-slate-12 outline outline-1 outline-n-weak"
        :placeholder="$t('FOLLOW_UPS.AI_BUILDER_PLACEHOLDER')"
      />
      <div class="flex justify-end">
        <NextButton
          sm
          solid
          blue
          icon="i-ph-sparkle-fill"
          :is-loading="isGeneratingAi"
          :disabled="isGeneratingAi"
          :label="
            isGeneratingAi
              ? $t('FOLLOW_UPS.AI_BUILDER_GENERATING')
              : $t('FOLLOW_UPS.AI_BUILDER_GENERATE')
          "
          @click="generateWithAi"
        />
      </div>

      <div
        v-if="aiDraft"
        class="flex flex-col gap-3 p-3 rounded-lg bg-n-background outline outline-1 outline-n-weak"
      >
        <div class="flex flex-col gap-1">
          <span class="text-xs font-medium text-n-slate-11">
            {{ $t('FOLLOW_UPS.AI_BUILDER_PREVIEW') }}
          </span>
          <span class="text-sm font-medium text-n-slate-12">
            {{ aiDraft.name }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ aiDraft.description }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ $t('FOLLOW_UPS.STEPS') }}: {{ aiDraft.steps?.length || 0 }}
          </span>
        </div>
        <div class="flex flex-wrap gap-2">
          <NextButton
            sm
            solid
            blue
            :label="$t('FOLLOW_UPS.AI_BUILDER_APPLY')"
            @click="applyAiDraft"
          />
          <NextButton
            sm
            faded
            slate
            :label="$t('FOLLOW_UPS.AI_BUILDER_DISCARD')"
            @click="discardAiDraft"
          />
        </div>
      </div>
    </div>

    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-n-slate-12">
        {{ $t('FOLLOW_UPS.NAME') }}
      </label>
      <input
        v-model="name"
        class="w-full px-3 py-2 text-sm rounded-lg reset-base bg-n-background text-n-slate-12 outline outline-1 outline-n-weak"
      />
    </div>

    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-n-slate-12">
        {{ $t('FOLLOW_UPS.DESCRIPTION_LABEL') }}
      </label>
      <textarea
        v-model="description"
        rows="2"
        class="w-full px-3 py-2 text-sm rounded-lg reset-base bg-n-background text-n-slate-12 outline outline-1 outline-n-weak"
      />
    </div>

    <div class="grid gap-4 sm:grid-cols-2">
      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('FOLLOW_UPS.TRIGGER_MODE') }}
        </label>
        <select
          v-model="triggerMode"
          class="w-full px-3 py-2 text-sm rounded-lg reset-base bg-n-background text-n-slate-12 outline outline-1 outline-n-weak"
        >
          <option value="manual">
            {{ $t('FOLLOW_UPS.TRIGGER_MODES.manual') }}
          </option>
          <option value="automation">
            {{ $t('FOLLOW_UPS.TRIGGER_MODES.automation') }}
          </option>
          <option value="both">
            {{ $t('FOLLOW_UPS.TRIGGER_MODES.both') }}
          </option>
        </select>
      </div>
      <label class="flex items-center gap-2 mt-6 text-sm text-n-slate-12">
        <input v-model="active" type="checkbox" />
        {{ $t('FOLLOW_UPS.ACTIVE') }}
      </label>
    </div>

    <div class="flex flex-col gap-4">
      <div class="flex items-center justify-between">
        <h3 class="mb-0 text-base font-medium text-n-slate-12">
          {{ $t('FOLLOW_UPS.STEPS') }}
          <span class="text-n-slate-11">({{ steps.length }})</span>
        </h3>
        <NextButton
          sm
          faded
          slate
          :label="$t('FOLLOW_UPS.ADD_STEP')"
          @click="addStep"
        />
      </div>

      <div
        v-for="(step, index) in steps"
        :key="index"
        class="flex flex-col gap-3 p-4 rounded-lg outline outline-1 outline-n-weak"
      >
        <div class="flex items-center justify-between">
          <h4 class="mb-0 text-sm font-semibold text-n-slate-12">
            #{{ index + 1 }}
          </h4>
          <NextButton
            v-if="steps.length > 1"
            xs
            ghost
            ruby
            :label="$t('FOLLOW_UPS.REMOVE_STEP')"
            @click="removeStep(index)"
          />
        </div>

        <div class="grid gap-3 sm:grid-cols-3">
          <div class="flex flex-col gap-1">
            <label class="text-xs text-n-slate-11">
              {{ $t('FOLLOW_UPS.WAIT_VALUE') }}
            </label>
            <input
              v-model.number="step.wait.value"
              type="number"
              min="1"
              class="w-full px-2 py-1.5 text-sm rounded-lg reset-base bg-n-background outline outline-1 outline-n-weak"
            />
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-xs text-n-slate-11">
              {{ $t('FOLLOW_UPS.WAIT_UNIT') }}
            </label>
            <select
              v-model="step.wait.unit"
              class="w-full px-2 py-1.5 text-sm rounded-lg reset-base bg-n-background outline outline-1 outline-n-weak"
            >
              <option value="minutes">
                {{ $t('FOLLOW_UPS.UNITS.minutes') }}
              </option>
              <option value="hours">{{ $t('FOLLOW_UPS.UNITS.hours') }}</option>
              <option value="days">{{ $t('FOLLOW_UPS.UNITS.days') }}</option>
              <option value="weeks">{{ $t('FOLLOW_UPS.UNITS.weeks') }}</option>
            </select>
          </div>
          <label class="flex items-center gap-2 mt-5 text-sm text-n-slate-12">
            <input v-model="step.wait.business_hours" type="checkbox" />
            {{ $t('FOLLOW_UPS.BUSINESS_HOURS') }}
          </label>
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-xs text-n-slate-11">
            {{ $t('FOLLOW_UPS.ON_FAIL') }}
          </label>
          <select
            v-model="step.on_fail"
            class="w-full px-2 py-1.5 text-sm rounded-lg reset-base bg-n-background outline outline-1 outline-n-weak"
          >
            <option value="abort">{{ $t('FOLLOW_UPS.ON_FAIL_ABORT') }}</option>
            <option value="skip">{{ $t('FOLLOW_UPS.ON_FAIL_SKIP') }}</option>
          </select>
        </div>

        <div class="flex flex-col gap-2">
          <div class="flex items-center justify-between">
            <span class="text-xs font-medium text-n-slate-11">
              {{ $t('FOLLOW_UPS.ACTIONS') }}
            </span>
            <NextButton xs faded slate label="+" @click="addAction(step)" />
          </div>
          <ul class="flex flex-col gap-2 p-0 m-0 list-none">
            <li
              v-for="(action, actionIndex) in step.actions"
              :key="actionIndex"
              class="flex flex-col gap-2"
            >
              <AutomationActionInput
                v-model="step.actions[actionIndex]"
                :action-types="actionTypes"
                :dropdown-values="getDropdownValues(action.action_name)"
                :show-action-input="showActionInput(action)"
                @remove-action="removeAction(step, actionIndex)"
                @reset-action="resetAction(action)"
              />
              <FollowUpSendMessageParams
                v-if="action.action_name === 'send_message'"
                v-model="step.actions[actionIndex]"
              />
            </li>
          </ul>
        </div>

        <div class="flex flex-col gap-2">
          <NextButton
            xs
            faded
            slate
            :label="$t('FOLLOW_UPS.BRANCH')"
            @click="toggleBranch(index)"
          />
          <div
            v-if="step.branch"
            class="grid gap-2 p-3 rounded-lg bg-n-alpha-black2 sm:grid-cols-2"
          >
            <div class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-11">
                {{ $t('FOLLOW_UPS.BRANCH_THEN') }}
              </label>
              <input
                v-model.number="step.branch.then_goto"
                type="number"
                min="0"
                class="px-2 py-1.5 text-sm rounded-lg reset-base bg-n-background outline outline-1 outline-n-weak"
              />
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-xs text-n-slate-11">
                {{ $t('FOLLOW_UPS.BRANCH_ELSE') }}
              </label>
              <input
                v-model.number="step.branch.else_goto"
                type="number"
                min="0"
                class="px-2 py-1.5 text-sm rounded-lg reset-base bg-n-background outline outline-1 outline-n-weak"
              />
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="flex justify-end">
      <NextButton
        solid
        blue
        :is-loading="isSaving"
        :label="$t('FOLLOW_UPS.SAVE')"
        @click="onSave"
      />
    </div>
  </div>
</template>
