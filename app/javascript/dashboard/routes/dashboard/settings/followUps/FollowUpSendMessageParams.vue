<script setup>
import { ref, computed } from 'vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import FollowUpWhatsAppTemplateModal from './FollowUpWhatsAppTemplateModal.vue';

const action = defineModel({
  type: Object,
  required: true,
});

const showTemplateModal = ref(false);

const isTemplateMessage = computed(() => {
  const params = action.value.action_params;
  return Boolean(
    params &&
      typeof params === 'object' &&
      !Array.isArray(params) &&
      params.template_params
  );
});

const textContent = computed({
  get() {
    const params = action.value.action_params;
    if (typeof params === 'string') return params;
    if (Array.isArray(params)) return params[0] || '';
    if (params && typeof params === 'object') return params.message || '';
    return '';
  },
  set(value) {
    action.value = {
      ...action.value,
      action_params: value,
    };
  },
});

const templateName = computed(
  () => action.value.action_params?.template_params?.name || ''
);

const openTemplateModal = () => {
  showTemplateModal.value = true;
};

const onTemplateSelected = payload => {
  action.value = {
    ...action.value,
    action_params: {
      message: payload.message,
      template_params: payload.template_params,
      inbox_id: payload.inbox_id,
    },
  };
};

const clearTemplate = () => {
  if (!isTemplateMessage.value) return;
  action.value = {
    ...action.value,
    action_params: action.value.action_params.message || '',
  };
};
</script>

<template>
  <div class="flex flex-col gap-2 pl-0">
    <div class="flex flex-wrap gap-2">
      <NextButton
        xs
        :solid="!isTemplateMessage"
        :faded="isTemplateMessage"
        :slate="isTemplateMessage"
        :label="$t('FOLLOW_UPS.SEND_AS_TEXT')"
        @click="clearTemplate"
      />
      <NextButton
        xs
        :solid="isTemplateMessage"
        :faded="!isTemplateMessage"
        :slate="!isTemplateMessage"
        icon="i-ri-whatsapp-line"
        :label="$t('FOLLOW_UPS.SEND_AS_WHATSAPP_TEMPLATE')"
        @click="openTemplateModal"
      />
    </div>

    <div
      v-if="isTemplateMessage"
      class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-black2"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{
            $t('FOLLOW_UPS.TEMPLATE_SELECTED', {
              name: templateName,
            })
          }}
        </span>
        <NextButton
          xs
          faded
          slate
          :label="$t('FOLLOW_UPS.CHANGE_WHATSAPP_TEMPLATE')"
          @click="openTemplateModal"
        />
      </div>
      <p class="mb-0 text-sm whitespace-pre-wrap text-n-slate-11">
        {{ textContent }}
      </p>
    </div>

    <WootMessageEditor
      v-else
      v-model="textContent"
      rows="4"
      enable-variables
      :placeholder="$t('AUTOMATION.ACTION.TEAM_MESSAGE_INPUT_PLACEHOLDER')"
      class="[&_.ProseMirror-menubar]:hidden px-3 py-1 bg-n-alpha-1 rounded-lg outline outline-1 outline-n-weak dark:outline-n-strong"
    />

    <FollowUpWhatsAppTemplateModal
      v-model:show="showTemplateModal"
      @close="showTemplateModal = false"
      @select="onTemplateSelected"
    />
  </div>
</template>
