require 'rails_helper'

RSpec.describe Whatsapp::TemplateProcessorService do
  describe '#call with Brazil payment_request buttons' do
    let(:template) do
      {
        'name' => '01_aviso_mensalidade_em_atraso',
        'language' => 'pt_BR',
        'status' => 'APPROVED',
        'parameter_format' => 'NAMED',
        'components' => [
          {
            'type' => 'BODY',
            'text' => 'Olá {{first_name}}, valor {{order_total}}'
          },
          {
            'type' => 'BUTTONS',
            'buttons' => [
              { 'type' => 'QUICK_REPLY', 'text' => 'Reagendar' },
              {
                'type' => 'PAYMENT_REQUEST',
                'text' => 'Open payment link',
                'payment_setting' => {
                  'type' => 'PAYMENT_LINK',
                  'payment_link' => { 'uri' => 'https://example.com/pay' }
                }
              },
              {
                'type' => 'PAYMENT_REQUEST',
                'text' => 'Copy Pix code',
                'payment_setting' => {
                  'type' => 'PIX_DYNAMIC_CODE',
                  'pix_dynamic_code' => { 'code' => 'sample' }
                }
              }
            ]
          }
        ]
      }
    end

    let(:channel) { instance_double(Channel::Whatsapp, message_templates: [template]) }

    let(:template_params) do
      {
        'name' => '01_aviso_mensalidade_em_atraso',
        'language' => 'pt_BR',
        'processed_params' => {
          'body' => {
            'first_name' => 'Ana',
            'order_total' => 'R$ 99,90'
          },
          'buttons' => [
            nil,
            {
              'type' => 'payment_request',
              'index' => 1,
              'payment_setting' => {
                'type' => 'payment_link',
                'payment_link' => { 'uri' => 'https://loc.fit/pagamento/22327' }
              }
            },
            {
              'type' => 'payment_request',
              'index' => 2,
              'payment_setting' => {
                'type' => 'pix_dynamic_code',
                'pix_dynamic_code' => { 'code' => '00020101021226700014br.gov.bcb.pix' }
              }
            }
          ]
        }
      }
    end

    it 'builds Meta Cloud API components with payment_request actions and correct indexes' do
      name, _namespace, language, components = described_class.new(
        channel: channel,
        template_params: template_params
      ).call

      expect(name).to eq('01_aviso_mensalidade_em_atraso')
      expect(language).to eq('pt_BR')
      expect(components).to include(
        hash_including(
          type: 'body',
          parameters: contain_exactly(
            hash_including(type: 'text', parameter_name: 'first_name', text: 'Ana'),
            hash_including(type: 'text', parameter_name: 'order_total', text: 'R$ 99,90')
          )
        )
      )
      expect(components).to include(
        {
          type: 'button',
          sub_type: 'payment_request',
          index: 1,
          parameters: [{
            type: 'action',
            action: {
              payment_request: {
                payment_setting: {
                  type: 'payment_link',
                  payment_link: { uri: 'https://loc.fit/pagamento/22327' }
                }
              }
            }
          }]
        }
      )
      expect(components).to include(
        {
          type: 'button',
          sub_type: 'payment_request',
          index: 2,
          parameters: [{
            type: 'action',
            action: {
              payment_request: {
                payment_setting: {
                  type: 'pix_dynamic_code',
                  pix_dynamic_code: { code: '00020101021226700014br.gov.bcb.pix' }
                }
              }
            }
          }]
        }
      )
    end
  end
end
