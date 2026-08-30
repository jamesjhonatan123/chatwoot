import {
  replaceTemplateVariables,
  buildTemplateParameters,
  processVariable,
  allKeysRequired,
  isButtonParameterComplete,
  isWhatsAppTemplateComplete,
  buildPaymentRequestButtonParameter,
} from '../templateHelper';
import { templates } from '../../store/modules/specs/inboxes/templateFixtures';

describe('templateHelper', () => {
  const technicianTemplate = templates.find(t => t.name === 'technician_visit');

  describe('processVariable', () => {
    it('should remove curly braces from variables', () => {
      expect(processVariable('{{name}}')).toBe('name');
      expect(processVariable('{{1}}')).toBe('1');
      expect(processVariable('{{customer_id}}')).toBe('customer_id');
    });
  });

  describe('allKeysRequired', () => {
    it('should return true when all keys have values', () => {
      const obj = { name: 'John', age: '30' };
      expect(allKeysRequired(obj)).toBe(true);
    });

    it('should return false when some keys are empty', () => {
      const obj = { name: 'John', age: '' };
      expect(allKeysRequired(obj)).toBe(false);
    });

    it('should return true for empty object', () => {
      expect(allKeysRequired({})).toBe(true);
    });
  });

  describe('replaceTemplateVariables', () => {
    const templateText =
      "Hi {{1}}, we're scheduling a technician visit to {{2}} on {{3}} between {{4}} and {{5}}. Please confirm if this time slot works for you.";

    it('should replace all variables with provided values', () => {
      const processedParams = {
        body: {
          1: 'John',
          2: '123 Main St',
          3: '2025-01-15',
          4: '10:00 AM',
          5: '2:00 PM',
        },
      };

      const result = replaceTemplateVariables(templateText, processedParams);
      expect(result).toBe(
        "Hi John, we're scheduling a technician visit to 123 Main St on 2025-01-15 between 10:00 AM and 2:00 PM. Please confirm if this time slot works for you."
      );
    });

    it('should keep original variable format when no replacement value provided', () => {
      const processedParams = {
        body: {
          1: 'John',
          3: '2025-01-15',
        },
      };

      const result = replaceTemplateVariables(templateText, processedParams);
      expect(result).toContain('John');
      expect(result).toContain('2025-01-15');
      expect(result).toContain('{{2}}');
      expect(result).toContain('{{4}}');
      expect(result).toContain('{{5}}');
    });

    it('should handle empty processedParams', () => {
      const result = replaceTemplateVariables(templateText, {});
      expect(result).toBe(templateText);
    });
  });

  describe('buildTemplateParameters', () => {
    it('should build parameters for template with body variables', () => {
      const result = buildTemplateParameters(technicianTemplate, false);

      expect(result.body).toEqual({
        1: '',
        2: '',
        3: '',
        4: '',
        5: '',
      });
    });

    it('should include header parameters when hasMediaHeader is true', () => {
      const imageTemplate = templates.find(
        t => t.name === 'order_confirmation'
      );
      const result = buildTemplateParameters(imageTemplate, true);

      expect(result.header).toEqual({
        media_url: '',
        media_type: 'image',
      });
    });

    it('should not include header parameters when hasMediaHeader is false', () => {
      const result = buildTemplateParameters(technicianTemplate, false);
      expect(result.header).toBeUndefined();
    });

    it('should handle template with no body component', () => {
      const templateWithoutBody = {
        components: [{ type: 'HEADER', format: 'TEXT' }],
      };

      const result = buildTemplateParameters(templateWithoutBody, false);
      expect(result).toEqual({});
    });

    it('should handle template with no variables', () => {
      const templateWithoutVars = templates.find(
        t => t.name === 'no_variable_template'
      );
      const result = buildTemplateParameters(templateWithoutVars, false);

      expect(result.body).toBeUndefined();
    });

    it('should handle URL buttons with variables for non-authentication templates', () => {
      const templateWithUrlButton = {
        category: 'MARKETING',
        components: [
          {
            type: 'BODY',
            text: 'Check out our website at {{site_url}}',
          },
          {
            type: 'BUTTONS',
            buttons: [
              {
                type: 'URL',
                url: 'https://example.com/{{campaign_id}}',
                text: 'Visit Site',
              },
            ],
          },
        ],
      };

      const result = buildTemplateParameters(templateWithUrlButton, false);
      expect(result.buttons).toEqual([
        {
          type: 'url',
          parameter: '',
          url: 'https://example.com/{{campaign_id}}',
          variables: ['campaign_id'],
        },
      ]);
    });

    it('should handle templates with no variables but a media header', () => {
      const emptyTemplate = templates.find(
        t => t.name === 'no_variable_template'
      );
      const result = buildTemplateParameters(emptyTemplate);
      // hasMediaHeader is derived from the template, so the document header is kept.
      expect(result.body).toBeUndefined();
      expect(result.header).toEqual({
        media_url: '',
        media_type: 'document',
        media_name: '',
      });
    });

    it('should build parameters for templates with multiple component types', () => {
      const complexTemplate = {
        components: [
          { type: 'HEADER', format: 'IMAGE' },
          { type: 'BODY', text: 'Hi {{1}}, your order {{2}} is ready!' },
          { type: 'FOOTER', text: 'Thank you for your business' },
          {
            type: 'BUTTONS',
            buttons: [{ type: 'URL', url: 'https://example.com/{{3}}' }],
          },
        ],
      };

      const result = buildTemplateParameters(complexTemplate, true);

      expect(result.header).toEqual({
        media_url: '',
        media_type: 'image',
      });
      expect(result.body).toEqual({ 1: '', 2: '' });
      expect(result.buttons).toEqual([
        {
          type: 'url',
          parameter: '',
          url: 'https://example.com/{{3}}',
          variables: ['3'],
        },
      ]);
    });

    it('should handle copy code buttons correctly', () => {
      const copyCodeTemplate = templates.find(
        t => t.name === 'discount_coupon'
      );
      const result = buildTemplateParameters(copyCodeTemplate, false);

      expect(result.body).toBeDefined();
      expect(result.buttons).toEqual([
        {
          type: 'copy_code',
          parameter: '',
        },
      ]);
    });

    it('should handle Brazil payment_request buttons', () => {
      const paymentTemplate = {
        category: 'UTILITY',
        components: [
          {
            type: 'BODY',
            text: 'Olá, {{first_name}}! Valor {{order_total}}',
          },
          {
            type: 'BUTTONS',
            buttons: [
              { type: 'QUICK_REPLY', text: 'Reagendar pagamento' },
              {
                type: 'PAYMENT_REQUEST',
                text: 'Open payment link',
                payment_setting: {
                  type: 'PAYMENT_LINK',
                  payment_link: {
                    uri: 'https://loc.fit/pagamento/{{ id }}',
                  },
                },
              },
              {
                type: 'PAYMENT_REQUEST',
                text: 'Copy Pix code',
                payment_setting: {
                  type: 'PIX_DYNAMIC_CODE',
                  pix_dynamic_code: { code: 'sample' },
                },
              },
            ],
          },
        ],
      };

      const result = buildTemplateParameters(paymentTemplate, false);

      expect(result.body).toEqual({ first_name: '', order_total: '' });
      expect(result.buttons[1]).toEqual({
        type: 'payment_request',
        index: 1,
        label: 'Open payment link',
        payment_setting: {
          type: 'payment_link',
          payment_link: { uri: '' },
        },
      });
      expect(result.buttons[2]).toEqual({
        type: 'payment_request',
        index: 2,
        label: 'Copy Pix code',
        payment_setting: {
          type: 'pix_dynamic_code',
          pix_dynamic_code: { code: '' },
        },
      });
      expect(isButtonParameterComplete(result.buttons[1])).toBe(false);
      expect(
        isButtonParameterComplete({
          ...result.buttons[1],
          payment_setting: {
            type: 'payment_link',
            payment_link: { uri: 'https://loc.fit/pagamento/1' },
          },
        })
      ).toBe(true);
    });

    it('should build payment request button parameter from Meta template button', () => {
      const button = buildPaymentRequestButtonParameter(
        {
          type: 'PAYMENT_REQUEST',
          text: 'Copy Boleto code',
          payment_setting: {
            type: 'boleto',
            boleto: { digitable_line: 'sample' },
          },
        },
        0
      );

      expect(button).toEqual({
        type: 'payment_request',
        index: 0,
        label: 'Copy Boleto code',
        payment_setting: {
          type: 'boleto',
          boleto: { digitable_line: '' },
        },
      });
    });

    it('should handle templates with document headers', () => {
      const documentTemplate = templates.find(
        t => t.name === 'purchase_receipt'
      );
      const result = buildTemplateParameters(documentTemplate, true);

      expect(result.header).toEqual({
        media_url: '',
        media_type: 'document',
        media_name: '',
      });
      expect(result.body).toEqual({
        1: '',
        2: '',
        3: '',
      });
    });

    it('should handle video header templates', () => {
      const videoTemplate = templates.find(t => t.name === 'training_video');
      const result = buildTemplateParameters(videoTemplate, true);

      expect(result.header).toEqual({
        media_url: '',
        media_type: 'video',
      });
      expect(result.body).toEqual({
        name: '',
        date: '',
      });
    });
  });

  describe('enhanced format validation', () => {
    it('should validate enhanced format structure', () => {
      const processedParams = {
        body: { 1: 'John', 2: 'Order123' },
        header: {
          media_url: 'https://example.com/image.jpg',
          media_type: 'image',
        },
        buttons: [{ type: 'copy_code', parameter: 'SAVE20' }],
      };

      // Test that structure is properly formed
      expect(processedParams.body).toBeDefined();
      expect(typeof processedParams.body).toBe('object');
      expect(processedParams.header).toBeDefined();
      expect(Array.isArray(processedParams.buttons)).toBe(true);
    });

    it('should handle empty component sections', () => {
      const processedParams = {
        body: {},
        header: {},
        buttons: [],
      };

      expect(allKeysRequired(processedParams.body)).toBe(true);
      expect(allKeysRequired(processedParams.header)).toBe(true);
      expect(processedParams.buttons.length).toBe(0);
    });

    it('should validate parameter completeness', () => {
      const incompleteParams = {
        body: { 1: 'John', 2: '' },
      };

      expect(allKeysRequired(incompleteParams.body)).toBe(false);
    });

    it('should handle edge cases in processVariable', () => {
      expect(processVariable('{{')).toBe('');
      expect(processVariable('}}')).toBe('');
      expect(processVariable('')).toBe('');
      expect(processVariable('{{nested{{variable}}}}')).toBe('nestedvariable');
    });

    it('should handle special characters in template variables', () => {
      /* eslint-disable no-template-curly-in-string */
      const templateText =
        'Welcome {{user_name}}, your order #{{order_id}} costs ${{amount}}';
      /* eslint-enable no-template-curly-in-string */
      const processedParams = {
        body: {
          user_name: 'John & Jane',
          order_id: '12345',
          amount: '99.99',
        },
      };

      const result = replaceTemplateVariables(templateText, processedParams);
      expect(result).toBe(
        'Welcome John & Jane, your order #12345 costs $99.99'
      );
    });

    it('should handle templates with mixed parameter types', () => {
      const mixedTemplate = {
        components: [
          { type: 'HEADER', format: 'VIDEO' },
          { type: 'BODY', text: 'Order {{order_id}} status: {{status}}' },
          { type: 'FOOTER', text: 'Thank you' },
          {
            type: 'BUTTONS',
            buttons: [
              { type: 'URL', url: 'https://track.com/{{order_id}}' },
              { type: 'COPY_CODE' },
              { type: 'PHONE_NUMBER', phone_number: '+1234567890' },
            ],
          },
        ],
      };

      const result = buildTemplateParameters(mixedTemplate, true);

      expect(result.header).toEqual({
        media_url: '',
        media_type: 'video',
      });
      expect(result.body).toEqual({
        order_id: '',
        status: '',
      });
      expect(result.buttons).toHaveLength(2); // URL and COPY_CODE (PHONE_NUMBER doesn't need parameters)
      expect(result.buttons[0].type).toBe('url');
      expect(result.buttons[1].type).toBe('copy_code');
    });

    it('should handle templates with no processable components', () => {
      const emptyTemplate = {
        components: [
          { type: 'HEADER', format: 'TEXT', text: 'Static Header' },
          { type: 'BODY', text: 'Static body with no variables' },
          { type: 'FOOTER', text: 'Static footer' },
        ],
      };

      const result = buildTemplateParameters(emptyTemplate, false);
      expect(result).toEqual({});
    });

    it('should validate that replaceTemplateVariables preserves unreplaced variables', () => {
      const templateText = 'Hi {{name}}, order {{order_id}} is {{status}}';
      const partialParams = {
        body: {
          name: 'John',
          // order_id missing
          status: 'ready',
        },
      };

      const result = replaceTemplateVariables(templateText, partialParams);
      expect(result).toBe('Hi John, order {{order_id}} is ready');
      expect(result).toContain('{{order_id}}'); // Unreplaced variable preserved
    });
  });
  // O CTA de pagamento do Brasil nao existe no helper compartilhado
  // (@chatwoot/utils): entra por cima dele. Estes testes guardam essa camada,
  // que e a que mais sofre quando o upstream mexe em template.
  describe('botao de Payment Request', () => {
    const templateComPix = {
      name: 'aviso_mensalidade',
      components: [
        { type: 'BODY', text: 'Olá {{nome}}' },
        {
          type: 'BUTTONS',
          buttons: [
            { type: 'QUICK_REPLY', text: 'Reagendar' },
            {
              type: 'PAYMENT_REQUEST',
              text: 'Copiar código Pix',
              payment_setting: { type: 'PIX_DYNAMIC_CODE' },
            },
          ],
        },
      ],
    };

    it('monta o botao de pagamento na mesma posicao que a Meta usa', () => {
      const params = buildTemplateParameters(templateComPix);

      expect(params.body).toEqual({ nome: '' });
      expect(params.buttons[0]).toBeUndefined();
      expect(params.buttons[1]).toEqual({
        type: 'payment_request',
        index: 1,
        label: 'Copiar código Pix',
        payment_setting: {
          type: 'pix_dynamic_code',
          pix_dynamic_code: { code: '' },
        },
      });
    });

    it('nao considera completo enquanto o codigo Pix estiver vazio', () => {
      const params = buildTemplateParameters(templateComPix);
      params.body.nome = 'Ana';

      expect(isWhatsAppTemplateComplete(templateComPix, params)).toBe(false);

      params.buttons[1].payment_setting.pix_dynamic_code.code = '000201';
      expect(isWhatsAppTemplateComplete(templateComPix, params)).toBe(true);
    });

    it('nao cobra `parameter` do botao de pagamento', () => {
      // isWhatsAppComplete sozinho exige button.parameter, que o CTA de
      // pagamento nunca tem — sem a nossa camada o formulario travava.
      const params = buildTemplateParameters(templateComPix);
      params.body.nome = 'Ana';
      params.buttons[1].payment_setting.pix_dynamic_code.code = '000201';

      expect(params.buttons[1].parameter).toBeUndefined();
      expect(isWhatsAppTemplateComplete(templateComPix, params)).toBe(true);
    });

    it('ainda cobra o parametro dos botoes comuns', () => {
      const templateComUrl = {
        name: 'rastreio',
        components: [
          { type: 'BODY', text: 'Pedido enviado' },
          {
            type: 'BUTTONS',
            buttons: [
              {
                type: 'URL',
                text: 'Rastrear',
                url: 'https://loc.fit/{{codigo}}',
              },
            ],
          },
        ],
      };

      const params = buildTemplateParameters(templateComUrl);
      expect(isWhatsAppTemplateComplete(templateComUrl, params)).toBe(false);

      params.buttons[0].parameter = 'ABC123';
      expect(isWhatsAppTemplateComplete(templateComUrl, params)).toBe(true);
    });

    it('ignora botao de pagamento sem tipo reconhecivel', () => {
      const semTipo = {
        name: 'sem_tipo',
        components: [
          { type: 'BODY', text: 'Olá' },
          {
            type: 'BUTTONS',
            buttons: [{ type: 'PAYMENT_REQUEST', text: 'Pagar' }],
          },
        ],
      };

      expect(buildTemplateParameters(semTipo).buttons).toBeUndefined();
    });
  });
});
