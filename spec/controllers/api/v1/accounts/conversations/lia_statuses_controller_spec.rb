require 'rails_helper'

# Selo da LIA na conversa. Formas de falhar:
# - atendente sem acesso a caixa le ou muda o estado da loja;
# - o token da LIA vaza para o navegador, ou campo extra da LIA passa direto;
# - LIA fora do ar derruba a tela (tem de responder "indisponivel");
# - o toggle nao leva quem clicou, ou aceita acao que nao seja ligar/desligar;
# - 409/404 da LIA viram 502 e o atendente nao ve o motivo.
RSpec.describe 'Conversation LIA Status API', type: :request do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:lia_url) { 'http://lia.test' }
  let(:status_endpoint) { "#{lia_url}/api/lia-status/chatwoot" }
  let(:show_url) { api_v1_account_conversation_lia_status_url(account_id: account.id, conversation_id: conversation.display_id) }
  let(:toggle_url) { toggle_api_v1_account_conversation_lia_status_url(account_id: account.id, conversation_id: conversation.display_id) }
  let(:json) { { 'Content-Type' => 'application/json' } }
  let(:respondendo) do
    { store_id: '334', state: 'respondendo', reason: 'normal', label: 'Respondendo', until: nil, by: nil, action: 'desligar', extra: 'x' }
  end

  around do |example|
    with_modified_env(LIA_API_URL: lia_url, LIA_ADMIN_API_TOKEN: 'segredo-de-teste') { example.run }
  end

  it 'denies an agent without access to the inbox' do
    stub = stub_request(:any, /lia-status/)

    get show_url, headers: agent.create_new_auth_token, as: :json
    post toggle_url, params: { lia_action: 'desligar' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(stub).not_to have_been_requested
  end

  context 'with an agent that has access to the inbox' do
    before { create(:inbox_member, inbox: conversation.inbox, user: agent) }

    it 'shows the store state for the conversation inbox, without extra fields' do
      stub = stub_request(:get, status_endpoint)
             .with(query: { account_id: account.id, inbox_id: conversation.inbox_id },
                   headers: { 'X-Admin-Token' => 'segredo-de-teste' })
             .to_return(status: 200, body: respondendo.to_json, headers: json)

      get show_url, headers: agent.create_new_auth_token, as: :json

      expect(stub).to have_been_requested
      expect(response.parsed_body).to eq(respondendo.except(:extra).stringify_keys)
      expect(response.body).not_to include('segredo-de-teste')
    end

    it 'answers unavailable when LIA is down' do
      stub_request(:get, status_endpoint).with(query: hash_including({})).to_timeout

      get show_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['state']).to be_nil
      expect(response.parsed_body['label']).to eq('Estado da LIA indisponível')
    end

    it 'toggles the whole store, sending who clicked' do
      silencio = respondendo.merge(state: 'silencio', reason: 'excecao_off', label: 'Em silêncio até 19:00: desligada por X', action: 'ligar')
      stub = stub_request(:post, status_endpoint)
             .with(body: { account_id: account.id, inbox_id: conversation.inbox_id, action: 'desligar', by: agent.available_name }.to_json)
             .to_return(status: 200, body: silencio.to_json, headers: json)

      post toggle_url, params: { lia_action: 'desligar' }, headers: agent.create_new_auth_token, as: :json

      expect(stub).to have_been_requested
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['state']).to eq('silencio')
    end

    it 'refuses an unknown action without calling LIA' do
      stub = stub_request(:post, status_endpoint)

      post toggle_url, params: { lia_action: 'apagar' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(stub).not_to have_been_requested
    end

    it 'passes the reason when there is nothing to do or no store' do
      detail = { detail: { message: 'Em silêncio até 19:00: horário de atendimento humano',
                           status: respondendo.merge(state: 'silencio', action: 'ligar') } }
      stub_request(:post, status_endpoint).to_return(status: 409, body: detail.to_json, headers: json)

      post toggle_url, params: { lia_action: 'desligar' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body['message']).to start_with('Em silêncio até 19:00')
      expect(response.parsed_body['state']).to eq('silencio')

      stub_request(:post, status_endpoint)
        .to_return(status: 404, body: { detail: { message: 'Esta caixa não está vinculada a uma loja da LIA.' } }.to_json, headers: json)
      post toggle_url, params: { lia_action: 'desligar' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['message']).to eq('Esta caixa não está vinculada a uma loja da LIA.')
    end
  end
end
