<script setup>
/**
 * This component handles parsing and sending WhatsApp message templates.
 * It works as follows:
 * 1. Displays the template text with variable placeholders.
 * 2. Generates input fields for each variable in the template.
 * 3. Validates that all variables are filled before sending.
 * 4. Replaces placeholders with user-provided values.
 * 5. Emits events to send the processed message or reset the template.
 */
import { ref, computed, onMounted, watch } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { requiredIf } from '@vuelidate/validators';
import { useI18n } from 'vue-i18n';

import Input from 'dashboard/components-next/input/Input.vue';
import {
  buildTemplateParameters,
  allKeysRequired,
  replaceTemplateVariables,
  isButtonParameterComplete,
  inferPaymentSettingType,
  PAYMENT_SETTING_TYPES,
  DEFAULT_LANGUAGE,
  DEFAULT_CATEGORY,
  COMPONENT_TYPES,
  MEDIA_FORMATS,
  findComponentByType,
} from 'dashboard/helper/templateHelper';

const props = defineProps({
  template: {
    type: Object,
    default: () => ({}),
    validator: value => {
      if (!value || typeof value !== 'object') return false;
      if (!value.components || !Array.isArray(value.components)) return false;
      return true;
    },
  },
});

const emit = defineEmits([
  'sendMessage',
  'scheduleMessage',
  'resetTemplate',
  'back',
]);

const { t } = useI18n();

const processedParams = ref({});

const languageLabel = computed(() => {
  return `${t('WHATSAPP_TEMPLATES.PARSER.LANGUAGE')}: ${props.template.language || DEFAULT_LANGUAGE}`;
});

const categoryLabel = computed(() => {
  return `${t('WHATSAPP_TEMPLATES.PARSER.CATEGORY')}: ${props.template.category || DEFAULT_CATEGORY}`;
});

const headerComponent = computed(() => {
  return findComponentByType(props.template, COMPONENT_TYPES.HEADER);
});

const bodyComponent = computed(() => {
  return findComponentByType(props.template, COMPONENT_TYPES.BODY);
});

const bodyText = computed(() => {
  return bodyComponent.value?.text || '';
});

const hasMediaHeader = computed(() =>
  MEDIA_FORMATS.includes(headerComponent.value?.format)
);

const formatType = computed(() => {
  const format = headerComponent.value?.format;
  return format ? format.charAt(0) + format.slice(1).toLowerCase() : '';
});

const isDocumentTemplate = computed(() => {
  return headerComponent.value?.format?.toLowerCase() === 'document';
});

const hasVariables = computed(() => {
  return bodyText.value?.match(/{{([^}]+)}}/g) !== null;
});

const hasButtonParameters = computed(() => {
  return (
    Array.isArray(processedParams.value.buttons) &&
    processedParams.value.buttons.some(button => Boolean(button))
  );
});

const showParameterForm = computed(() => {
  return (
    hasVariables.value || hasMediaHeader.value || hasButtonParameters.value
  );
});

const renderedTemplate = computed(() => {
  return replaceTemplateVariables(bodyText.value, processedParams.value);
});

const isFormInvalid = computed(() => {
  if (!showParameterForm.value) return false;

  if (hasMediaHeader.value && !processedParams.value.header?.media_url) {
    return true;
  }

  if (hasVariables.value && processedParams.value.body) {
    const hasEmptyBodyVariable = Object.values(processedParams.value.body).some(
      value => !value
    );
    if (hasEmptyBodyVariable) return true;
  }

  if (processedParams.value.buttons) {
    const hasEmptyButtonParameter = processedParams.value.buttons.some(
      button => button && !isButtonParameterComplete(button)
    );
    if (hasEmptyButtonParameter) return true;
  }

  return false;
});

const paymentSettingType = button => inferPaymentSettingType(button?.payment_setting);

const paymentButtonLabel = (button, index) => {
  if (button?.label) return button.label;
  return t('WHATSAPP_TEMPLATES.PARSER.BUTTON_LABEL', { index: index + 1 });
};

const paymentFieldPlaceholder = button => {
  const settingType = paymentSettingType(button);
  if (settingType === PAYMENT_SETTING_TYPES.PAYMENT_LINK) {
    return t('WHATSAPP_TEMPLATES.PARSER.PAYMENT_LINK_URI');
  }
  if (settingType === PAYMENT_SETTING_TYPES.PIX_DYNAMIC_CODE) {
    return t('WHATSAPP_TEMPLATES.PARSER.PIX_DYNAMIC_CODE');
  }
  if (settingType === PAYMENT_SETTING_TYPES.BOLETO) {
    return t('WHATSAPP_TEMPLATES.PARSER.BOLETO_DIGITABLE_LINE');
  }
  return t('WHATSAPP_TEMPLATES.PARSER.BUTTON_PARAMETER');
};

const v$ = useVuelidate(
  {
    processedParams: {
      requiredIfKeysPresent: requiredIf(hasVariables),
      allKeysRequired,
    },
  },
  { processedParams }
);

const initializeTemplateParameters = () => {
  processedParams.value = buildTemplateParameters(
    props.template,
    hasMediaHeader.value
  );
};

const updateMediaUrl = value => {
  processedParams.value.header ??= {};
  processedParams.value.header.media_url = value;
};

const updateMediaName = value => {
  processedParams.value.header ??= {};
  processedParams.value.header.media_name = value;
};

const buildMessagePayload = () => {
  const { name, category, language, namespace } = props.template;

  return {
    message: renderedTemplate.value,
    templateParams: {
      name,
      category,
      language,
      namespace,
      processed_params: processedParams.value,
    },
  };
};

const sendMessage = () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  emit('sendMessage', buildMessagePayload());
};

const scheduleMessage = () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  emit('scheduleMessage', buildMessagePayload());
};

const resetTemplate = () => {
  emit('resetTemplate');
};

const goBack = () => {
  emit('back');
};

onMounted(initializeTemplateParameters);

watch(
  () => props.template,
  () => {
    initializeTemplateParameters();
    v$.value.$reset();
  },
  { deep: true }
);

defineExpose({
  processedParams,
  hasVariables,
  hasMediaHeader,
  isDocumentTemplate,
  headerComponent,
  renderedTemplate,
  v$,
  updateMediaUrl,
  updateMediaName,
  sendMessage,
  scheduleMessage,
  resetTemplate,
  goBack,
});
</script>

<template>
  <div>
    <div class="flex flex-col gap-4 p-4 mb-4 rounded-lg bg-n-alpha-black2">
      <div class="flex justify-between items-center">
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ template.name }}
        </h3>
        <span class="text-xs text-n-slate-11">
          {{ languageLabel }}
        </span>
      </div>

      <div class="flex flex-col gap-2">
        <div class="rounded-md">
          <div class="text-sm whitespace-pre-wrap text-n-slate-12">
            {{ renderedTemplate }}
          </div>
        </div>
      </div>

      <div class="text-xs text-n-slate-11">
        {{ categoryLabel }}
      </div>
    </div>

    <div v-if="showParameterForm">
      <div v-if="hasMediaHeader" class="mb-4">
        <p class="mb-2.5 text-sm font-semibold">
          {{
            $t('WHATSAPP_TEMPLATES.PARSER.MEDIA_HEADER_LABEL', {
              type: formatType,
            }) || `${formatType} Header`
          }}
        </p>
        <div class="flex items-center mb-2.5">
          <Input
            :model-value="processedParams.header?.media_url || ''"
            type="url"
            class="flex-1"
            :placeholder="
              t('WHATSAPP_TEMPLATES.PARSER.MEDIA_URL_LABEL', {
                type: formatType,
              })
            "
            @update:model-value="updateMediaUrl"
          />
        </div>
        <div v-if="isDocumentTemplate" class="flex items-center mb-2.5">
          <Input
            :model-value="processedParams.header?.media_name || ''"
            type="text"
            class="flex-1"
            :placeholder="
              t('WHATSAPP_TEMPLATES.PARSER.DOCUMENT_NAME_PLACEHOLDER')
            "
            @update:model-value="updateMediaName"
          />
        </div>
      </div>

      <!-- Body Variables Section -->
      <div v-if="processedParams.body">
        <p class="mb-2.5 text-sm font-semibold">
          {{ $t('WHATSAPP_TEMPLATES.PARSER.VARIABLES_LABEL') }}
        </p>
        <div
          v-for="(variable, key) in processedParams.body"
          :key="`body-${key}`"
          class="flex items-center mb-2.5"
        >
          <Input
            v-model="processedParams.body[key]"
            type="text"
            class="flex-1"
            :placeholder="
              t('WHATSAPP_TEMPLATES.PARSER.VARIABLE_PLACEHOLDER', {
                variable: key,
              })
            "
          />
        </div>
      </div>

      <!-- Button Variables Section -->
      <div v-if="hasButtonParameters">
        <p class="mb-2.5 text-sm font-semibold">
          {{ t('WHATSAPP_TEMPLATES.PARSER.BUTTON_PARAMETERS') }}
        </p>
        <template
          v-for="(button, index) in processedParams.buttons"
          :key="`button-${index}`"
        >
          <div v-if="button" class="mb-3">
            <p
              v-if="button.type === 'payment_request'"
              class="mb-1.5 text-xs font-medium text-n-slate-11"
            >
              {{ paymentButtonLabel(button, index) }}
            </p>

            <Input
              v-if="button.type === 'payment_request' && paymentSettingType(button) === 'payment_link'"
              v-model="processedParams.buttons[index].payment_setting.payment_link.uri"
              type="url"
              class="flex-1"
              :placeholder="paymentFieldPlaceholder(button)"
            />
            <Input
              v-else-if="
                button.type === 'payment_request' &&
                paymentSettingType(button) === 'pix_dynamic_code'
              "
              v-model="
                processedParams.buttons[index].payment_setting.pix_dynamic_code
                  .code
              "
              type="text"
              class="flex-1"
              :placeholder="paymentFieldPlaceholder(button)"
            />
            <Input
              v-else-if="
                button.type === 'payment_request' &&
                paymentSettingType(button) === 'boleto'
              "
              v-model="
                processedParams.buttons[index].payment_setting.boleto
                  .digitable_line
              "
              type="text"
              class="flex-1"
              :placeholder="paymentFieldPlaceholder(button)"
            />
            <Input
              v-else
              v-model="processedParams.buttons[index].parameter"
              type="text"
              class="flex-1"
              :placeholder="t('WHATSAPP_TEMPLATES.PARSER.BUTTON_PARAMETER')"
            />
          </div>
        </template>
      </div>
      <p
        v-if="v$.$dirty && v$.$invalid"
        class="p-2.5 text-center rounded-md bg-n-ruby-9/20 text-n-ruby-9"
      >
        {{ $t('WHATSAPP_TEMPLATES.PARSER.FORM_ERROR_MESSAGE') }}
      </p>
    </div>

    <slot
      name="actions"
      :send-message="sendMessage"
      :schedule-message="scheduleMessage"
      :reset-template="resetTemplate"
      :go-back="goBack"
      :is-valid="!v$.$invalid"
      :disabled="isFormInvalid"
    />
  </div>
</template>
