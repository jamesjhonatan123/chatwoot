require 'rails_helper'

describe Whatsapp::TemplateProcessorService do
  subject(:processed_components) do
    described_class.new(channel: channel, template_params: template_params).call.last
  end

  let(:channel) { instance_double(Channel::Whatsapp, message_templates: [template]) }
  let(:template_params) do
    {
      'name' => template['name'],
      'language' => template['language'],
      'processed_params' => { 'header' => header_params }
    }
  end

  context 'with a positional text header' do
    let(:template) do
      {
        'name' => 'positional_header',
        'language' => 'en_US',
        'status' => 'APPROVED',
        'parameter_format' => 'POSITIONAL',
        'components' => [{ 'type' => 'HEADER', 'format' => 'TEXT', 'text' => 'Welcome {{1}}' }]
      }
    end
    let(:header_params) { { '1' => 'Jane' } }

    it 'builds a positional text parameter' do
      expect(processed_components).to eq([
                                           {
                                             type: 'header',
                                             parameters: [{ type: 'text', text: 'Jane' }]
                                           }
                                         ])
    end
  end

  context 'with a named text header' do
    let(:template) do
      {
        'name' => 'named_header',
        'language' => 'en_US',
        'status' => 'APPROVED',
        'parameter_format' => 'NAMED',
        'components' => [{ 'type' => 'HEADER', 'format' => 'TEXT', 'text' => "Welcome {{#{parameter_name}}}" }]
      }
    end
    let(:header_params) { { parameter_name => 'Jane' } }

    %w[customer_name media_type media_name].each do |name|
      context "when the parameter is #{name}" do
        let(:parameter_name) { name }

        it 'preserves the parameter name' do
          expect(processed_components).to eq([
                                               {
                                                 type: 'header',
                                                 parameters: [{ type: 'text', parameter_name: parameter_name, text: 'Jane' }]
                                               }
                                             ])
        end
      end
    end
  end

  context 'with positional body parameters' do
    let(:template) do
      {
        'name' => 'positional_body',
        'language' => 'en_US',
        'status' => 'APPROVED',
        'parameter_format' => 'POSITIONAL',
        'components' => [{ 'type' => 'BODY', 'text' => '{{1}} / {{2}}' }]
      }
    end
    let(:template_params) do
      {
        'name' => template['name'],
        'language' => template['language'],
        'processed_params' => {
          'body' => {
            '2' => 'Bob',
            '1' => 'Alice'
          }
        }
      }
    end

    it 'orders parameters by their positional key' do
      expect(processed_components).to eq([
                                           {
                                             type: 'body',
                                             parameters: [
                                               { type: 'text', text: 'Alice' },
                                               { type: 'text', text: 'Bob' }
                                             ]
                                           }
                                         ])
    end
  end

  context 'with a media header' do
    let(:template) do
      {
        'name' => 'document_header',
        'language' => 'en_US',
        'status' => 'APPROVED',
        'parameter_format' => 'POSITIONAL',
        'components' => [{ 'type' => 'HEADER', 'format' => 'DOCUMENT' }]
      }
    end
    let(:header_params) do
      {
        'media_url' => 'https://example.com/report.pdf',
        'media_type' => 'document',
        'media_name' => 'report.pdf'
      }
    end

    it 'uses media metadata to build the attachment parameter' do
      expect(processed_components).to eq([
                                           {
                                             type: 'header',
                                             parameters: [
                                               {
                                                 type: 'document',
                                                 document: {
                                                   link: 'https://example.com/report.pdf',
                                                   filename: 'report.pdf'
                                                 }
                                               }
                                             ]
                                           }
                                         ])
    end
  end

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
