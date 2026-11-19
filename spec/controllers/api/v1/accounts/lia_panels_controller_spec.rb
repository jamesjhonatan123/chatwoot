require 'rails_helper'

# Painel da LIA. Formas de falhar:
# - pede a LIA com caixa a que o atendente nao tem acesso (numeros de outra loja);
# - a LIA devolve conversa de caixa que o atendente nao ve e ela chega ao navegador;
# - a loja do filtro deixa passar caixa que o atendente nao ve;
# - conversa sem nome, caixa ou responsavel (o painel mostraria so numeros);
# - LIA fora do ar derruba a tela;
# - o token da LIA vaza para o navegador.
RSpec.describe 'LIA panel API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:inbox) { create(:inbox, account: account, name: 'WhatsApp Batel') }
  let(:other_inbox) { create(:inbox, account: account, name: 'WhatsApp Joinville') }
  let(:lia_url) { 'http://lia.test' }
  let(:panel_endpoint) { "#{lia_url}/api/lia-status/chatwoot/panel" }
  let(:show_url) { api_v1_account_lia_panel_url(account_id: account.id) }
  let(:json) { { 'Content-Type' => 'application/json' } }
  let(:mine) { create(:conversation, account: account, inbox: inbox, assignee: agent, contact: create(:contact, account: account, name: 'Carla')) }
  let(:hidden) { create(:conversation, account: account, inbox: other_inbox) }

  around do |example|
    with_modified_env(LIA_API_URL: lia_url, LIA_ADMIN_API_TOKEN: 'segredo-de-teste') { example.run }
  end

  before { create(:inbox_member, inbox: inbox, user: agent) }

  def panel_body
    row = ->(conversation, stage) { { chatwoot_conversation_id: conversation.display_id, inbox_id: conversation.inbox_id, stage: stage } }
    {
      period: { key: '7d' }, summary: { conversations: 2, autonomy_pct: 50.0 }, funnel: [], stalled: [],
      links: { product: { sent: 1, clicked: 1, paid: 0 } }, handoff_reasons: [], trend: { bucket: 'day', points: [] },
      live: [row.call(mine, 'recebeu_link').merge(last_message: 'quero a esteira', minutes_since_last: 2)],
      conversations: [row.call(mine, 'recebeu_link'), row.call(hidden, 'pagou')]
    }
  end

  it 'asks the LIA only for the inboxes the agent sees and drops any conversation outside them' do
    request = stub_request(:get, panel_endpoint)
              .with(query: { account_id: account.id, inbox_ids: inbox.id.to_s, period: '7d' },
                    headers: { 'X-Admin-Token' => 'segredo-de-teste' })
              .to_return(status: 200, body: panel_body.to_json, headers: json)

    get show_url, params: { period: '7d' }, headers: agent.create_new_auth_token, as: :json

    expect(request).to have_been_requested
    body = response.parsed_body
    expect(body['lia_available']).to be(true)
    expect(body['conversations'].pluck('id')).to eq([mine.display_id])
    expect(body['conversations'].first).to include('contact_name' => 'Carla', 'inbox_name' => 'WhatsApp Batel',
                                                   'assignee_name' => agent.available_name, 'stage' => 'recebeu_link', 'status' => 'open')
    expect(body['live'].first).to include('id' => mine.display_id, 'last_message' => 'quero a esteira')
    expect(body['summary']['autonomy_pct']).to eq(50.0)
    expect(response.body).not_to include('segredo-de-teste')
  end

  it 'narrows to the chosen store, never beyond the inboxes the agent sees' do
    stores = [{ store_id: '334', name: 'Batel', inbox_ids: [inbox.id, other_inbox.id], state: 'respondendo' }]
    stub_request(:get, "#{lia_url}/api/lia-status/chatwoot/account").with(query: { account_id: account.id })
                                                                    .to_return(status: 200, body: { stores: stores }.to_json, headers: json)
    request = stub_request(:get, panel_endpoint)
              .with(query: { account_id: account.id, inbox_ids: inbox.id.to_s, period: 'hoje' })
              .to_return(status: 200, body: panel_body.to_json, headers: json)

    get show_url, params: { store_id: '334' }, headers: agent.create_new_auth_token, as: :json

    expect(request).to have_been_requested
    expect(response).to have_http_status(:ok)
  end

  it 'answers without numbers when the LIA is down' do
    stub_request(:get, panel_endpoint).with(query: hash_including({})).to_return(status: 500)

    get show_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('lia_available' => false, 'period' => 'hoje')
  end
end
