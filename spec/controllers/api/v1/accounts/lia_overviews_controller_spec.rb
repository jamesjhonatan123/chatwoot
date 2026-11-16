require 'rails_helper'

# Faixa "LIA parada" e fila "Esperando a equipe". Formas de falhar:
# - conversa respondida ha pouco, resolvida, ou de caixa sem acesso entra na fila;
# - a fila nao vem do mais antigo para o mais novo;
# - o motivo errado: transferida pela LIA, LIA parada na loja ou so sem resposta;
# - atendente ve loja de caixa a que nao tem acesso, ou liga a LIA dela pela faixa;
# - LIA fora do ar derruba a tela (a fila tem de vir mesmo assim, sem lojas);
# - o token da LIA vaza para o navegador.
RSpec.describe 'LIA overview API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, name: 'WhatsApp Batel') }
  let(:other_inbox) { create(:inbox, account: account, name: 'WhatsApp Joinville') }
  let(:lia_url) { 'http://lia.test' }
  let(:stores_endpoint) { "#{lia_url}/api/lia-status/chatwoot/account" }
  let(:show_url) { api_v1_account_lia_overview_url(account_id: account.id) }
  let(:toggle_url) { toggle_api_v1_account_lia_overview_url(account_id: account.id) }
  let(:json) { { 'Content-Type' => 'application/json' } }
  let(:stores) do
    [
      { store_id: '334', name: 'Curitiba Batel', inbox_ids: [inbox.id], state: 'silencio', reason: 'excecao_off',
        label: 'Em silêncio até meia-noite: desligada por Brenda', until: '2026-11-17T03:00:00+00:00', by: 'Brenda',
        since: '2026-11-16T16:10:00+00:00', action: 'ligar' },
      { store_id: '2863', name: 'Joinville', inbox_ids: [other_inbox.id], state: 'respondendo', reason: 'normal',
        label: 'Respondendo', action: 'desligar' }
    ]
  end

  around do |example|
    with_modified_env(LIA_API_URL: lia_url, LIA_ADMIN_API_TOKEN: 'segredo-de-teste') { example.run }
  end

  before { create(:inbox_member, inbox: inbox, user: agent) }

  def waiting_conversation(minutes:, target_inbox: inbox, status: :open, labels: [])
    conversation = create(:conversation, account: account, inbox: target_inbox)
    conversation.update!(label_list: labels) if labels.any?
    create(:message, conversation: conversation, account: account, inbox: target_inbox, message_type: :incoming,
                     content: "cliente esperando #{minutes}")
    # Depois da mensagem: a fala do cliente reabre conversa resolvida.
    conversation.update_columns(waiting_since: minutes.minutes.ago, status: Conversation.statuses[status]) # rubocop:disable Rails/SkipsModelValidations
    conversation
  end

  def stub_stores(body = { stores: stores })
    stub_request(:get, stores_endpoint)
      .with(query: { account_id: account.id }, headers: { 'X-Admin-Token' => 'segredo-de-teste' })
      .to_return(status: 200, body: body.to_json, headers: json)
  end

  it 'lists only open conversations waiting more than 15 minutes in inboxes the agent sees, oldest first' do
    stub_stores
    recent = waiting_conversation(minutes: 5)
    oldest = waiting_conversation(minutes: 905)
    middle = waiting_conversation(minutes: 34)
    resolved = waiting_conversation(minutes: 60, status: :resolved)
    hidden = waiting_conversation(minutes: 120, target_inbox: other_inbox)

    get show_url, headers: agent.create_new_auth_token, as: :json

    body = response.parsed_body
    ids = body['waiting']['conversations'].pluck('id')
    expect(ids).to eq([oldest.display_id, middle.display_id])
    expect(ids).not_to include(recent.display_id, resolved.display_id, hidden.display_id)
    expect(body['waiting']['count']).to eq(2)
    expect(body['threshold_minutes']).to eq(15)
    expect(body['waiting']['conversations'].first['last_message']).to eq('cliente esperando 905')
    expect(body['waiting']['conversations'].first['inbox_name']).to eq('WhatsApp Batel')
    expect(response.body).not_to include('segredo-de-teste')
  end

  it 'gives the reason: handed off by LIA, LIA paused in the store, or just unanswered' do
    stub_stores(stores: [stores.first.merge(state: 'respondendo', reason: 'normal')])
    handed = waiting_conversation(minutes: 50, labels: ['lia-transferiu'])
    plain = waiting_conversation(minutes: 40)

    get show_url, headers: agent.create_new_auth_token, as: :json
    reasons = response.parsed_body['waiting']['conversations'].to_h { |row| [row['id'], row['reason']] }
    expect(reasons).to eq(handed.display_id => 'lia_transferiu', plain.display_id => 'sem_resposta')

    stub_stores
    get show_url, headers: agent.create_new_auth_token, as: :json
    reasons = response.parsed_body['waiting']['conversations'].to_h { |row| [row['id'], row['reason']] }
    expect(reasons).to eq(handed.display_id => 'lia_transferiu', plain.display_id => 'lia_parada')
  end

  it 'shows only the stores of inboxes the agent sees, with how many wait there' do
    stub_stores
    waiting_conversation(minutes: 74)
    waiting_conversation(minutes: 20)

    get show_url, headers: agent.create_new_auth_token, as: :json

    body = response.parsed_body
    expect(body['lia_available']).to be(true)
    expect(body['stores'].pluck('store_id')).to eq(['334'])
    store = body['stores'].first
    expect(store).to include('name' => 'Curitiba Batel', 'state' => 'silencio', 'by' => 'Brenda', 'waiting_count' => 2)
    expect(Time.zone.parse(store['oldest_waiting_since'])).to be_within(1.minute).of(74.minutes.ago)
  end

  it 'still lists who is waiting when LIA is down' do
    stub_request(:get, stores_endpoint).with(query: hash_including({})).to_timeout
    waiting_conversation(minutes: 30)

    get show_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['lia_available']).to be(false)
    expect(response.parsed_body['stores']).to eq([])
    expect(response.parsed_body['waiting']['count']).to eq(1)
  end

  it 'turns LIA on through an inbox of the store the agent sees, with who clicked' do
    stub_stores
    toggle = stub_request(:post, "#{lia_url}/api/lia-status/chatwoot")
             .with(body: hash_including('inbox_id' => inbox.id, 'action' => 'ligar', 'by' => agent.available_name))
             .to_return(status: 200, body: stores.first.merge(state: 'respondendo').to_json, headers: json)

    post toggle_url, params: { store_id: '334', lia_action: 'ligar' }, headers: agent.create_new_auth_token, as: :json

    expect(toggle).to have_been_requested
    expect(response.parsed_body['state']).to eq('respondendo')
  end

  # Revisão do Gemini: a última mensagem era uma consulta por conversa, e a contagem duas
  # por loja. A tela consulta a cada minuto por atendente aberto.
  it 'does not grow the number of queries with conversations and stores' do
    stub_stores
    count_queries = lambda do
      queries = 0
      callback = ->(*, payload) { queries += 1 unless payload[:name] == 'SCHEMA' || payload[:sql].start_with?('BEGIN', 'COMMIT') }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get show_url, headers: agent.create_new_auth_token, as: :json
      end
      queries
    end
    2.times { |i| waiting_conversation(minutes: 20 + i) }
    few = count_queries.call
    6.times { |i| waiting_conversation(minutes: 40 + i) }
    expect(count_queries.call).to eq(few)
  end

  it 'counts everyone waiting even beyond the 50 listed' do
    stub_stores
    stub_const("#{Api::V1::Accounts::LiaOverviewsController}::LIST_LIMIT", 2)
    3.times { |i| waiting_conversation(minutes: 20 + i) }

    get show_url, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body['waiting']['conversations'].size).to eq(2)
    expect(response.parsed_body['waiting']['count']).to eq(3)
  end

  it 'lets an administrator see every inbox without being a member' do
    stub_stores
    admin = create(:user, account: account, role: :administrator)
    waiting_conversation(minutes: 30, target_inbox: other_inbox)

    get show_url, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['waiting']['count']).to eq(1)
    expect(response.parsed_body['stores'].pluck('store_id')).to contain_exactly('334', '2863')
  end

  it 'answers 503, not 404, when LIA is down and someone clicks to turn it on' do
    stub_request(:get, stores_endpoint).with(query: hash_including({})).to_timeout

    post toggle_url, params: { store_id: '334', lia_action: 'ligar' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:service_unavailable)
  end

  it 'refuses to toggle a store whose inboxes the agent cannot see' do
    stub_stores
    toggle = stub_request(:post, "#{lia_url}/api/lia-status/chatwoot")

    post toggle_url, params: { store_id: '2863', lia_action: 'ligar' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:not_found)
    expect(toggle).not_to have_been_requested
  end
end
