import {
  processVariable,
  buildWhatsAppProcessedParams,
  isWhatsAppComplete,
  COMPONENT_TYPES,
} from '@chatwoot/utils';

// Constants and pure template helpers are shared with the mobile app via
// @chatwoot/utils so the logic lives in one place.
export {
  MEDIA_FORMATS,
  COMPONENT_TYPES,
  findComponentByType,
  processVariable,
  renderTemplatePreview,
} from '@chatwoot/utils';

export const DEFAULT_LANGUAGE = 'en';
export const DEFAULT_CATEGORY = 'UTILITY';
export const PAYMENT_SETTING_TYPES = {
  PAYMENT_LINK: 'payment_link',
  PIX_DYNAMIC_CODE: 'pix_dynamic_code',
  BOLETO: 'boleto',
};

export const allKeysRequired = value => {
  const keys = Object.keys(value);
  return keys.every(key => value[key]);
};

export const replaceTemplateVariables = (templateText, processedParams) => {
  return templateText.replace(/{{([^}]+)}}/g, (match, variable) => {
    const variableKey = processVariable(variable);
    return processedParams.body?.[variableKey] || `{{${variable}}}`;
  });
};

export const normalizePaymentSettingType = rawType => {
  const type = (rawType || '').toString().trim().toLowerCase();
  if (type === PAYMENT_SETTING_TYPES.PAYMENT_LINK || type === 'paymentlink') {
    return PAYMENT_SETTING_TYPES.PAYMENT_LINK;
  }
  if (
    type === PAYMENT_SETTING_TYPES.PIX_DYNAMIC_CODE ||
    type === 'pixdynamiccode'
  ) {
    return PAYMENT_SETTING_TYPES.PIX_DYNAMIC_CODE;
  }
  if (type === PAYMENT_SETTING_TYPES.BOLETO) {
    return PAYMENT_SETTING_TYPES.BOLETO;
  }
  return type;
};

export const inferPaymentSettingType = paymentSetting => {
  if (!paymentSetting || typeof paymentSetting !== 'object') return '';

  const fromType = normalizePaymentSettingType(paymentSetting.type);
  if (fromType) return fromType;

  if (paymentSetting.payment_link) return PAYMENT_SETTING_TYPES.PAYMENT_LINK;
  if (paymentSetting.pix_dynamic_code)
    return PAYMENT_SETTING_TYPES.PIX_DYNAMIC_CODE;
  if (paymentSetting.boleto) return PAYMENT_SETTING_TYPES.BOLETO;

  return '';
};

export const buildPaymentRequestButtonParameter = (button, index) => {
  const paymentSetting = button.payment_setting || {};
  const settingType = inferPaymentSettingType(paymentSetting);
  if (!settingType) return null;

  const entry = {
    type: 'payment_request',
    index,
    label: button.text || '',
    payment_setting: {
      type: settingType,
    },
  };

  if (settingType === PAYMENT_SETTING_TYPES.PAYMENT_LINK) {
    entry.payment_setting.payment_link = { uri: '' };
  } else if (settingType === PAYMENT_SETTING_TYPES.PIX_DYNAMIC_CODE) {
    entry.payment_setting.pix_dynamic_code = { code: '' };
  } else if (settingType === PAYMENT_SETTING_TYPES.BOLETO) {
    entry.payment_setting.boleto = { digitable_line: '' };
  }

  return entry;
};

export const isButtonParameterComplete = button => {
  if (!button) return true;

  if (button.type === 'payment_request') {
    const settingType = inferPaymentSettingType(button.payment_setting);
    if (settingType === PAYMENT_SETTING_TYPES.PAYMENT_LINK) {
      return Boolean(button.payment_setting?.payment_link?.uri?.trim());
    }
    if (settingType === PAYMENT_SETTING_TYPES.PIX_DYNAMIC_CODE) {
      return Boolean(button.payment_setting?.pix_dynamic_code?.code?.trim());
    }
    if (settingType === PAYMENT_SETTING_TYPES.BOLETO) {
      return Boolean(button.payment_setting?.boleto?.digitable_line?.trim());
    }
    return false;
  }

  return Boolean(button.parameter);
};

// O CTA de pagamento do Brasil so existe aqui: o helper compartilhado monta os
// botoes de URL e COPY_CODE, e estes entram por cima, na mesma posicao do
// buttons[] que a Meta usa.
export const addPaymentRequestButtons = (template, params) => {
  const buttonComponents = (template.components || []).filter(
    component => component.type === COMPONENT_TYPES.BUTTONS
  );

  buttonComponents.forEach(buttonComponent => {
    (buttonComponent.buttons || []).forEach((button, index) => {
      if (
        button.type !== 'PAYMENT_REQUEST' &&
        button.type !== 'payment_request'
      )
        return;

      const paymentButton = buildPaymentRequestButtonParameter(button, index);
      if (!paymentButton) return;

      if (!params.buttons) params.buttons = [];
      params.buttons[index] = paymentButton;
    });
  });

  return params;
};

// O segundo argumento (hasMediaHeader) e ignorado: o helper compartilhado deduz
// isso do proprio template. Fica na assinatura pelas chamadas antigas.
export const buildTemplateParameters = template =>
  addPaymentRequestButtons(template, buildWhatsAppProcessedParams(template));

// isWhatsAppComplete valida corpo, cabecalho e midia, mas so aceita botao com
// `parameter` preenchido — e o botao de pagamento nao tem parameter. Por isso os
// botoes saem da conta dele e passam pela nossa regra.
export const isWhatsAppTemplateComplete = (template, processedParams) => {
  const { buttons, ...rest } = processedParams;

  if (!isWhatsAppComplete(template, rest)) return false;

  return (buttons || []).every(
    button => !button || isButtonParameterComplete(button)
  );
};
