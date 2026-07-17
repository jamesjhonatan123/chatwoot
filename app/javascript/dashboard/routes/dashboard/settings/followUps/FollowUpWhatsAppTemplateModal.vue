<script setup>
import { ref, computed, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import TemplatesPicker from 'dashboard/components/widgets/conversation/WhatsappTemplates/TemplatesPicker.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'select', 'update:show']);

const inboxes = useMapGetter('inboxes/getInboxes');
const selectedWaTemplate = ref(null);
const selectedInboxId = ref(null);

const whatsappInboxes = computed(() =>
  (inboxes.value || []).filter(
    inbox =>
      inbox.channel_type === INBOX_TYPES.WHATSAPP ||
      (inbox.channel_type === INBOX_TYPES.TWILIO && inbox.medium === 'whatsapp')
  )
);

const localShow = computed({
  get: () => props.show,
  set: value => {
    emit('update:show', value);
    if (!value) emit('close');
  },
});

const modalHeaderContent = computed(() => {
  if (selectedWaTemplate.value) {
    return selectedWaTemplate.value.name;
  }
  return '';
});

watch(
  () => props.show,
  visible => {
    if (!visible) {
      selectedWaTemplate.value = null;
      return;
    }
    if (!selectedInboxId.value && whatsappInboxes.value.length) {
      selectedInboxId.value = whatsappInboxes.value[0].id;
    }
  }
);

const pickTemplate = template => {
  selectedWaTemplate.value = template;
};

const onResetTemplate = () => {
  selectedWaTemplate.value = null;
};

const onSelectTemplate = payload => {
  emit('select', {
    message: payload.message,
    template_params: payload.templateParams,
    inbox_id: selectedInboxId.value,
  });
  selectedWaTemplate.value = null;
  emit('close');
};

const onClose = () => {
  selectedWaTemplate.value = null;
  emit('close');
};
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onClose" size="modal-big">
    <woot-modal-header
      :header-title="$t('FOLLOW_UPS.WHATSAPP_TEMPLATE_MODAL_TITLE')"
      :header-content="
        modalHeaderContent || $t('FOLLOW_UPS.WHATSAPP_TEMPLATE_MODAL_SUBTITLE')
      "
    />
    <div class="flex flex-col gap-4 px-4 py-4 sm:px-8 sm:py-6">
      <div v-if="!selectedWaTemplate" class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('FOLLOW_UPS.WHATSAPP_INBOX') }}
        </label>
        <select
          v-model="selectedInboxId"
          class="w-full px-3 py-2 text-sm rounded-lg reset-base bg-n-background text-n-slate-12 outline outline-1 outline-n-weak"
        >
          <option
            v-for="inbox in whatsappInboxes"
            :key="inbox.id"
            :value="inbox.id"
          >
            {{ inbox.name }}
          </option>
        </select>
      </div>

      <p v-if="!whatsappInboxes.length" class="mb-0 text-sm text-n-slate-11">
        {{ $t('FOLLOW_UPS.WHATSAPP_INBOX_EMPTY') }}
      </p>

      <TemplatesPicker
        v-else-if="!selectedWaTemplate && selectedInboxId"
        :inbox-id="selectedInboxId"
        @on-select="pickTemplate"
      />

      <WhatsAppTemplateParser
        v-else-if="selectedWaTemplate"
        :template="selectedWaTemplate"
        @send-message="onSelectTemplate"
        @reset-template="onResetTemplate"
        @back="onResetTemplate"
      >
        <template #actions="{ sendMessage, resetTemplate, disabled }">
          <footer
            class="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end"
          >
            <NextButton
              faded
              slate
              type="button"
              class="w-full sm:w-auto"
              :label="$t('WHATSAPP_TEMPLATES.PARSER.GO_BACK_LABEL')"
              @click="resetTemplate"
            />
            <NextButton
              type="button"
              class="w-full sm:w-auto"
              :label="$t('FOLLOW_UPS.USE_WHATSAPP_TEMPLATE')"
              :disabled="disabled"
              @click="sendMessage"
            />
          </footer>
        </template>
      </WhatsAppTemplateParser>
    </div>
  </woot-modal>
</template>
