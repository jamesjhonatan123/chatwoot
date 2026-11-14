require 'rails_helper'
# Caminho que a LIA usa: o bot chama toggle_typing_status pela API, o evento passa pelo
# dispatcher assíncrono e o listener chama a Meta. Só a Meta é simulada (WebMock).
describe 'POST toggle_typing_status numa inbox da API oficial', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              provider_config: { 'api_key' => 'test_key', 'phone_number_id' => '123456789' },
                              validate_provider_config: false, sync_templates: false)
  end
  let(:conversation) { create(:conversation, account: account, inbox: whatsapp_channel.inbox) }

  before do
    stub_request(:get, %r{graph\.facebook\.com/.*/message_templates})
    Redis::Alfred.scan_each(match: 'whatsapp_typing:*') { |key| Redis::Alfred.delete(key) }
    create(:agent_bot_inbox, inbox: whatsapp_channel.inbox, agent_bot: agent_bot)
    create(:message, conversation: conversation, account: account, inbox: whatsapp_channel.inbox,
                     message_type: :incoming, source_id: 'wamid.da_api')
  end

  it 'leva lida + digitando ao WhatsApp do cliente' do
    meta = stub_request(:post, 'https://graph.facebook.com/v23.0/123456789/messages')
           .with(body: hash_including('status' => 'read', 'message_id' => 'wamid.da_api',
                                      'typing_indicator' => { 'type' => 'text' }))
           .to_return(status: 200, body: '{"success":true}')

    perform_enqueued_jobs do
      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_typing_status",
           headers: { api_access_token: agent_bot.access_token.token },
           params: { typing_status: 'on' },
           as: :json
    end

    expect(response).to have_http_status(:success)
    expect(meta).to have_been_requested.once
  end
end
