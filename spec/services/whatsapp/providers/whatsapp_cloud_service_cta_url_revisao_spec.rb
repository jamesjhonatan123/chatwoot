require 'rails_helper'

# Achados da revisão do PR #19: link no meio da frase deixava o corpo "Seu link é ." e o botão
# perdia a citação da mensagem respondida.
describe Whatsapp::Providers::WhatsappCloudService do
  subject(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  let(:whatsapp_channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let(:conversation) { create(:conversation, inbox: whatsapp_channel.inbox) }
  let(:endpoint) { 'https://graph.facebook.com/v13.0/123456789/messages' }
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:url) { 'https://loc.fit/finalizar-assinatura/?locfit_plan=17494&lia_ref=ab12' }
  let(:cta) { { url: url, display_text: 'Começar a treinar' } }

  before do
    stub_request(:get, 'https://graph.facebook.com/v14.0/123456789/message_templates?access_token=test_key')
  end

  it 'manda só o texto quando o link está no meio da frase' do
    message = create(:message, conversation: conversation, inbox: whatsapp_channel.inbox, message_type: :outgoing,
                               content: "Seu link é #{url}. Qualquer dúvida me chama.", content_attributes: { cta_url: cta })
    stub_request(:post, endpoint).with(body: hash_including(type: 'text'))
                                 .to_return(status: 200, body: { messages: [{ id: 'wamid.texto' }] }.to_json, headers: headers)

    expect(service.send_message('+5542999990000', message)).to eq 'wamid.texto'
    expect(a_request(:post, endpoint).with(body: hash_including(type: 'interactive'))).not_to have_been_made
  end

  it 'mantém a citação da mensagem respondida no botão' do
    da_cliente = create(:message, conversation: conversation, inbox: whatsapp_channel.inbox, message_type: :incoming,
                                  content: 'Quero o de 6 meses', source_id: 'wamid.cliente')
    message = create(:message, conversation: conversation, inbox: whatsapp_channel.inbox, message_type: :outgoing,
                               content: "Separei o plano pra você:\n#{url}",
                               content_attributes: { cta_url: cta, in_reply_to: da_cliente.id })
    stub = stub_request(:post, endpoint)
           .with(body: hash_including(type: 'interactive', context: { message_id: 'wamid.cliente' }))
           .to_return(status: 200, body: { messages: [{ id: 'wamid.botao' }] }.to_json, headers: headers)

    expect(service.send_message('+5542999990000', message)).to eq 'wamid.botao'
    expect(stub).to have_been_requested.once
  end
end
