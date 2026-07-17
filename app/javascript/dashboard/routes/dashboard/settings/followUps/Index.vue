<script setup>
import { onMounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ExecutionHistory from './ExecutionHistory.vue';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const uiFlags = useMapGetter('followUps/getUIFlags');
const workflows = useMapGetter('followUps/getWorkflows');
const analytics = useMapGetter('followUps/getAnalytics');

const isFetching = computed(
  () => uiFlags.value.isFetchingWorkflows || uiFlags.value.isFetchingAnalytics
);

onMounted(() => {
  store.dispatch('followUps/getWorkflows');
  store.dispatch('followUps/getAnalytics');
});

const goNew = () => router.push({ name: 'follow_ups_new' });
const goEdit = id =>
  router.push({ name: 'follow_ups_edit', params: { workflowId: id } });

const onDelete = async workflow => {
  if (workflow.system_preset) return;
  try {
    await store.dispatch('followUps/deleteWorkflow', workflow.id);
    useAlert(t('FOLLOW_UPS.DELETE_WORKFLOW_SUCCESS'));
  } catch (error) {
    useAlert(t('FOLLOW_UPS.DELETE_WORKFLOW_ERROR'));
  }
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <BaseSettingsHeader
      :title="$t('FOLLOW_UPS.HEADER')"
      :description="$t('FOLLOW_UPS.DESCRIPTION')"
    >
      <template #actions>
        <NextButton
          solid
          blue
          sm
          :label="$t('FOLLOW_UPS.HEADER_BTN_TXT')"
          @click="goNew"
        />
      </template>
    </BaseSettingsHeader>

    <div v-if="isFetching" class="flex justify-center py-8">
      <Spinner />
    </div>

    <template v-else>
      <div v-if="analytics" class="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div class="p-4 rounded-lg outline outline-1 outline-n-weak">
          <p class="mb-1 text-xs text-n-slate-11">
            {{ $t('FOLLOW_UPS.ANALYTICS_TOTALS') }}
          </p>
          <p class="mb-0 text-xl font-semibold text-n-slate-12">
            {{ analytics.totals?.runs || 0 }}
          </p>
        </div>
        <div class="p-4 rounded-lg outline outline-1 outline-n-weak">
          <p class="mb-1 text-xs text-n-slate-11">
            {{ $t('FOLLOW_UPS.ANALYTICS_COMPLETION') }}
          </p>
          <p class="mb-0 text-xl font-semibold text-n-slate-12">
            {{ analytics.completion_rate || 0 }}%
          </p>
        </div>
        <div class="p-4 rounded-lg outline outline-1 outline-n-weak">
          <p class="mb-1 text-xs text-n-slate-11">
            {{ $t('FOLLOW_UPS.ANALYTICS_REPLY_CANCEL') }}
          </p>
          <p class="mb-0 text-xl font-semibold text-n-slate-12">
            {{ analytics.reply_cancel_rate || 0 }}%
          </p>
        </div>
        <div class="p-4 rounded-lg outline outline-1 outline-n-weak">
          <p class="mb-1 text-xs text-n-slate-11">
            {{ $t('FOLLOW_UPS.ANALYTICS_STEPS') }}
          </p>
          <p class="mb-0 text-xl font-semibold text-n-slate-12">
            {{ analytics.steps?.done || 0 }}
          </p>
        </div>
      </div>

      <ul class="flex flex-col gap-3 m-0 list-none">
        <li
          v-for="workflow in workflows"
          :key="workflow.id"
          class="flex flex-col gap-3 p-4 rounded-lg outline outline-1 outline-n-weak sm:flex-row sm:items-center sm:justify-between"
        >
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <h3 class="mb-0 text-base font-medium text-n-slate-12">
                {{
                  workflow.preset_key
                    ? $t(`FOLLOW_UPS.PRESETS.${workflow.preset_key}`)
                    : workflow.name
                }}
              </h3>
              <span
                v-if="workflow.system_preset"
                class="px-2 py-0.5 text-xs rounded bg-n-brand/10 text-n-blue-11"
              >
                {{ $t('FOLLOW_UPS.PRESET_BADGE') }}
              </span>
            </div>
            <p class="mb-0 text-sm text-n-slate-11">
              {{
                workflow.preset_key
                  ? $t(`FOLLOW_UPS.PRESET_DESCRIPTIONS.${workflow.preset_key}`)
                  : workflow.description
              }}
            </p>
            <p class="mb-0 text-xs text-n-slate-11">
              {{
                $t('FOLLOW_UPS.STEPS_COUNT', {
                  count: workflow.steps?.length || 0,
                })
              }}
              {{ $t('FOLLOW_UPS.META_SEPARATOR') }}
              {{ $t(`FOLLOW_UPS.TRIGGER_MODES.${workflow.trigger_mode}`) }}
            </p>
          </div>
          <div class="flex gap-2">
            <NextButton
              sm
              faded
              slate
              :label="$t('FOLLOW_UPS.EDIT')"
              @click="goEdit(workflow.id)"
            />
            <NextButton
              v-if="!workflow.system_preset"
              sm
              faded
              ruby
              :label="$t('FOLLOW_UPS.DELETE')"
              @click="onDelete(workflow)"
            />
          </div>
        </li>
      </ul>

      <ExecutionHistory />
    </template>
  </div>
</template>
