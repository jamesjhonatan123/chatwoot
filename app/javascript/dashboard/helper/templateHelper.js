// Constants
export const DEFAULT_LANGUAGE = 'en';
export const DEFAULT_CATEGORY = 'UTILITY';
export const COMPONENT_TYPES = {
  HEADER: 'HEADER',
  BODY: 'BODY',
  BUTTONS: 'BUTTONS',
};
export const MEDIA_FORMATS = ['IMAGE', 'VIDEO', 'DOCUMENT'];

export const PAYMENT_SETTING_TYPES = {
  PAYMENT_LINK: 'payment_link',
  PIX_DYNAMIC_CODE: 'pix_dynamic_code',
  BOLETO: 'boleto',
};

export const findComponentByType = (template, type) =>
  template.components?.find(component => component.type === type);

export const processVariable = str => {
  return str.replace(/{{|}}/g, '');
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
  if (
    type === PAYMENT_SETTING_TYPES.PAYMENT_LINK ||
    type === 'paymentlink'
  ) {
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

export const buildTemplateParameters = (template, hasMediaHeaderValue) => {
  const allVariables = {};

  const bodyComponent = findComponentByType(template, COMPONENT_TYPES.BODY);
  const headerComponent = findComponentByType(template, COMPONENT_TYPES.HEADER);

  if (!bodyComponent) return allVariables;

  const templateString = bodyComponent.text;

  // Process body variables
  const matchedVariables = templateString.match(/{{([^}]+)}}/g);
  if (matchedVariables) {
    allVariables.body = {};
    matchedVariables.forEach(variable => {
      const key = processVariable(variable);
      allVariables.body[key] = '';
    });
  }

  if (hasMediaHeaderValue) {
    if (!allVariables.header) allVariables.header = {};
    allVariables.header.media_url = '';
    allVariables.header.media_type = headerComponent.format.toLowerCase();

    // For document templates, include media_name field for filename support
    if (headerComponent.format.toLowerCase() === 'document') {
      allVariables.header.media_name = '';
    }
  }

  // Process button variables
  const buttonComponents = template.components.filter(
    component => component.type === COMPONENT_TYPES.BUTTONS
  );

  buttonComponents.forEach(buttonComponent => {
    if (buttonComponent.buttons) {
      buttonComponent.buttons.forEach((button, index) => {
        // Handle URL buttons with variables
        if (button.type === 'URL' && button.url && button.url.includes('{{')) {
          const buttonVars = button.url.match(/{{([^}]+)}}/g) || [];
          if (buttonVars.length > 0) {
            if (!allVariables.buttons) allVariables.buttons = [];
            allVariables.buttons[index] = {
              type: 'url',
              parameter: '',
              url: button.url,
              variables: buttonVars.map(v => processVariable(v)),
            };
          }
        }

        // Handle copy code buttons
        if (button.type === 'COPY_CODE') {
          if (!allVariables.buttons) allVariables.buttons = [];
          allVariables.buttons[index] = {
            type: 'copy_code',
            parameter: '',
          };
        }

        // Brazil Payment Request CTA (Pix / Payment Link / Boleto)
        if (
          button.type === 'PAYMENT_REQUEST' ||
          button.type === 'payment_request'
        ) {
          const paymentButton = buildPaymentRequestButtonParameter(
            button,
            index
          );
          if (paymentButton) {
            if (!allVariables.buttons) allVariables.buttons = [];
            allVariables.buttons[index] = paymentButton;
          }
        }
      });
    }
  });

  return allVariables;
};
