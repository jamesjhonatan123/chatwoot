<script setup>
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

defineProps({
  template: {
    type: Object,
    default: () => ({}),
  },
  sendRenderedContent: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['sendMessage', 'scheduleMessage', 'resetTemplate']);

const handleSendMessage = payload => {
  emit('sendMessage', payload);
};

const handleScheduleMessage = payload => {
  emit('scheduleMessage', payload);
};

const handleResetTemplate = () => {
  emit('resetTemplate');
};
</script>

<template>
  <div class="w-full">
    <WhatsAppTemplateParser
      :template="template"
      :send-rendered-content="sendRenderedContent"
      @send-message="handleSendMessage"
      @schedule-message="handleScheduleMessage"
      @reset-template="handleResetTemplate"
    >
      <template
        #actions="{ sendMessage, scheduleMessage, resetTemplate, disabled }"
      >
        <footer class="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <NextButton
            faded
            slate
            type="reset"
            class="w-full sm:w-auto"
            :label="$t('WHATSAPP_TEMPLATES.PARSER.GO_BACK_LABEL')"
            @click="resetTemplate"
          />
          <NextButton
            faded
            slate
            type="button"
            class="w-full sm:w-auto"
            icon="i-lucide-calendar-clock"
            :label="
              $t('CONVERSATION_SIDEBAR.SCHEDULED_MESSAGES.SCHEDULE_TEMPLATE')
            "
            :disabled="disabled"
            @click="scheduleMessage"
          />
          <NextButton
            type="button"
            class="w-full sm:w-auto"
            :label="$t('WHATSAPP_TEMPLATES.PARSER.SEND_MESSAGE_LABEL')"
            :disabled="disabled"
            @click="sendMessage"
          />
        </footer>
      </template>
    </WhatsAppTemplateParser>
  </div>
</template>
