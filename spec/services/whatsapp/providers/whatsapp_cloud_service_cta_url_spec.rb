require 'rails_helper'

# Botão de link (interactive cta_url) da Cloud API: a LIA manda o link de checkout no texto e
# pede o botão em content_attributes.cta_url. O texto da conversa no Chatwoot fica com o link;
# para o cliente, o link sai do corpo e vira o botão. Se a Meta recusar o botão, sai o texto de antes.
describe Whatsapp::Providers::WhatsappCloudService do
  subject(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  let(:whatsapp_channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let(:conversation) { create(:conversation, inbox: whatsapp_channel.inbox) }
  let(:endpoint) { 'https://graph.facebook.com/v13.0/123456789/messages' }
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:url) { 'https://loc.fit/finalizar-assinatura/?produto=10&plano=price_6_months&lia_ref=ab12' }
  let(:content) { "Perfeito! Separei o plano de 6 meses pra você.\n\n👉 #{url}\n\nQualquer dúvida é só me chamar." }
  let(:cta) { { url: url, display_text: 'Começar a treinar' } }

  def outgoing(content_attributes)
    create(:message, conversation: conversation, inbox: whatsapp_channel.inbox, message_type: :outgoing,
                     content: content, content_attributes: content_attributes)
  end

  before do
    stub_request(:get, 'https://graph.facebook.com/v14.0/123456789/message_templates?access_token=test_key')
  end

  it 'manda o link como botão e tira o link do corpo' do
    stub = stub_request(:post, endpoint).with(
      body: {
        messaging_product: 'whatsapp', to: '+5542999990000', type: 'interactive',
        interactive: {
          type: 'cta_url',
          body: { text: "Perfeito! Separei o plano de 6 meses pra você.\n\nQualquer dúvida é só me chamar." },
          action: { name: 'cta_url', parameters: { display_text: 'Começar a treinar', url: url } }
        }
      }.to_json
    ).to_return(status: 200, body: { messages: [{ id: 'wamid.botao' }] }.to_json, headers: headers)

    expect(service.send_message('+5542999990000', outgoing(cta_url: cta))).to eq 'wamid.botao'
    expect(stub).to have_been_requested.once
  end

  it 'aceita content_attributes vindo como JSON com chaves em texto' do
    stub_request(:post, endpoint).with(body: hash_including(type: 'interactive'))
                                 .to_return(status: 200, body: { messages: [{ id: 'wamid.botao' }] }.to_json, headers: headers)

    expect(service.send_message('+5542999990000', outgoing('cta_url' => cta.stringify_keys))).to eq 'wamid.botao'
  end

  it 'manda o texto com o link quando a Meta recusa o botão, sem marcar a mensagem como falha' do
    stub_request(:post, endpoint).with(body: hash_including(type: 'interactive'))
                                 .to_return(status: 400, body: { error: { message: 'Unsupported interactive' } }.to_json, headers: headers)
    texto = stub_request(:post, endpoint).with(body: hash_including(type: 'text', text: { body: content, preview_url: true }))
                                         .to_return(status: 200, body: { messages: [{ id: 'wamid.texto' }] }.to_json, headers: headers)
    message = outgoing(cta_url: cta)

    expect(service.send_message('+5542999990000', message)).to eq 'wamid.texto'
    expect(texto).to have_been_requested.once
    expect(message.reload.status).not_to eq 'failed'
  end

  {
    'o link do botão não está no texto' => { url: 'https://loc.fit/outra-pagina/', display_text: 'Começar a treinar' },
    'o rótulo passa de 20 caracteres' => { url: 'https://loc.fit/finalizar-assinatura/?produto=10&plano=price_6_months&lia_ref=ab12',
                                           display_text: 'Começar a treinar agora mesmo' },
    'o link não é https' => { url: 'http://loc.fit/finalizar-assinatura/', display_text: 'Começar a treinar' },
    'falta o rótulo' => { url: 'https://loc.fit/finalizar-assinatura/?produto=10&plano=price_6_months&lia_ref=ab12' }
  }.each do |caso, pedido|
    it "manda só o texto quando #{caso}" do
      stub_request(:post, endpoint).with(body: hash_including(type: 'text'))
                                   .to_return(status: 200, body: { messages: [{ id: 'wamid.texto' }] }.to_json, headers: headers)

      expect(service.send_message('+5542999990000', outgoing(cta_url: pedido))).to eq 'wamid.texto'
      expect(a_request(:post, endpoint).with(body: hash_including(type: 'interactive'))).not_to have_been_made
    end
  end
end
