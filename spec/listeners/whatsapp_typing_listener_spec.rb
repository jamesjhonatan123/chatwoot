require 'rails_helper'

# Formas de falhar levantadas antes do código:
# 1. nota interna mostrando "digitando…" ao cliente;
# 2. inbox que não é a API oficial chamando a Meta;
# 3. conversa sem mensagem do cliente (ou só com mensagem velha demais para a Meta);
# 4. usar o id de uma mensagem nossa em vez do wamid da última do cliente;
# 5. várias chamadas por resposta enquanto alguém digita;
# 6. nenhuma chamada na resposta seguinte (a Meta apaga o indicador quando a resposta sai);
# 7. erro da Meta derrubando o job;
# 8. corpo, versão ou token errados na chamada.
describe WhatsappTypingListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              provider_config: { 'api_key' => 'test_key', 'phone_number_id' => '123456789' },
                              validate_provider_config: false, sync_templates: false)
  end
  let(:inbox) { whatsapp_channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:typing_url) { 'https://graph.facebook.com/v23.0/123456789/messages' }
  let(:typing_body) do
    { messaging_product: 'whatsapp', status: 'read', message_id: 'wamid.cliente2', typing_indicator: { type: 'text' } }.to_json
  end

  def typing_on(is_private: false)
    event = Events::Base.new(:'conversation.typing_on', Time.zone.now,
                             conversation: conversation, user: user, is_private: is_private)
    listener.conversation_typing_on(event)
  end

  def incoming(source_id, created_at: Time.current)
    create(:message, conversation: conversation, account: account, inbox: inbox,
                     message_type: :incoming, source_id: source_id, created_at: created_at)
  end

  before do
    stub_request(:get, %r{graph\.facebook\.com/.*/message_templates})
    Redis::Alfred.scan_each(match: 'whatsapp_typing:*') { |key| Redis::Alfred.delete(key) }
    incoming('wamid.cliente1', created_at: 2.minutes.ago)
    incoming('wamid.cliente2', created_at: 1.minute.ago)
    create(:message, conversation: conversation, account: account, inbox: inbox,
                     message_type: :outgoing, source_id: 'wamid.nossa', created_at: 2.minutes.ago)
  end

  it 'marca como lida e mostra digitando com o wamid da última mensagem do cliente' do
    request = stub_request(:post, typing_url)
              .with(body: typing_body, headers: { 'Authorization' => 'Bearer test_key' })
              .to_return(status: 200, body: { success: true }.to_json, headers: { 'Content-Type' => 'application/json' })

    typing_on

    expect(request).to have_been_requested.once
  end

  it 'não chama a Meta para nota interna, nem com is_private em texto' do
    typing_on(is_private: true)
    typing_on(is_private: 'true')

    expect(a_request(:post, typing_url)).not_to have_been_made
  end

  it 'não chama a Meta em inbox que não é a API oficial' do
    api_inbox = create(:inbox, account: account)
    conversation.update!(inbox: api_inbox)

    typing_on

    expect(a_request(:post, typing_url)).not_to have_been_made
  end

  it 'não chama a Meta sem mensagem do cliente dentro de 30 dias' do
    conversation.messages.incoming.each { |message| message.update!(created_at: 31.days.ago) }

    typing_on

    expect(a_request(:post, typing_url)).not_to have_been_made
  end

  it 'chama uma vez por resposta e de novo depois que a resposta sai' do
    request = stub_request(:post, typing_url).to_return(status: 200, body: '{"success":true}')

    3.times { typing_on }
    expect(request).to have_been_requested.once

    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing)
    typing_on
    expect(request).to have_been_requested.twice
  end

  it 'erro da Meta não levanta exceção' do
    stub_request(:post, typing_url).to_return(
      status: 400, body: { error: { message: 'Invalid parameter', code: 131_009 } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect { typing_on }.not_to raise_error
  end

  it 'falha de rede não levanta exceção' do
    stub_request(:post, typing_url).to_timeout

    expect { typing_on }.not_to raise_error
  end
end
