require 'rails_helper'

RSpec.describe 'Conversation LIA Suggestion API', type: :request do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:lia_url) { 'http://lia.test' }
  let(:suggestion_endpoint) { "#{lia_url}/api/chatwoot/suggestion" }
  let(:suggestion_id) { SecureRandom.uuid }
  let(:show_url) { api_v1_account_conversation_lia_suggestion_url(account_id: account.id, conversation_id: conversation.display_id) }
  let(:dismiss_url) { dismiss_api_v1_account_conversation_lia_suggestion_url(account_id: account.id, conversation_id: conversation.display_id) }

  around do |example|
    with_modified_env(LIA_API_URL: lia_url, LIA_ADMIN_API_TOKEN: 'segredo-de-teste') { example.run }
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/<id>/lia_suggestion' do
    it 'returns unauthorized for an unauthenticated user' do
      get show_url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies an agent without access to the inbox' do
      stub = stub_request(:post, suggestion_endpoint)

      get show_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(stub).not_to have_been_requested
    end

    context 'with an agent that has access to the inbox' do
      before { create(:inbox_member, inbox: conversation.inbox, user: agent) }

      it 'answers disabled without any HTTP call when the ENV is missing' do
        stub = stub_request(:post, suggestion_endpoint)

        with_modified_env(LIA_API_URL: nil, LIA_ADMIN_API_TOKEN: nil) do
          get show_url, headers: agent.create_new_auth_token, as: :json
        end

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq('suggestion' => nil, 'reason' => 'disabled')
        expect(stub).not_to have_been_requested
      end

      it 'passes the LIA payload through, sending ids and auth headers' do
        body = { suggestion: { id: suggestion_id, text: 'Oi!', source: 'canned', extra: 'x' }, reason: 'ok' }
        stub = stub_request(:post, suggestion_endpoint)
               .with(
                 body: { account_id: account.id, inbox_id: conversation.inbox_id, conversation_id: conversation.display_id }.to_json,
                 headers: { 'Authorization' => 'Bearer segredo-de-teste', 'X-Admin-Token' => 'segredo-de-teste' }
               )
               .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })

        get show_url, headers: agent.create_new_auth_token, as: :json

        expect(stub).to have_been_requested
        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(
          'suggestion' => { 'id' => suggestion_id, 'text' => 'Oi!', 'source' => 'canned' }, 'reason' => 'ok'
        )
      end

      it 'passes a null suggestion and its reason through' do
        stub_request(:post, suggestion_endpoint)
          .to_return(status: 200, body: { suggestion: nil, reason: 'no_pending' }.to_json, headers: { 'Content-Type' => 'application/json' })

        get show_url, headers: agent.create_new_auth_token, as: :json

        expect(response.parsed_body).to eq('suggestion' => nil, 'reason' => 'no_pending')
      end

      it 'answers reason error with status 200 when LIA returns 500' do
        stub_request(:post, suggestion_endpoint).to_return(status: 500, body: 'boom')

        get show_url, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq('suggestion' => nil, 'reason' => 'error')
      end

      it 'answers reason error with status 200 on timeout' do
        stub_request(:post, suggestion_endpoint).to_timeout

        get show_url, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq('suggestion' => nil, 'reason' => 'error')
      end

      it 'answers reason error with status 200 on invalid JSON' do
        stub_request(:post, suggestion_endpoint)
          .to_return(status: 200, body: '{nao e json', headers: { 'Content-Type' => 'application/json' })

        get show_url, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq('suggestion' => nil, 'reason' => 'error')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/<id>/lia_suggestion/dismiss' do
    before { create(:inbox_member, inbox: conversation.inbox, user: agent) }

    it 'returns unprocessable entity for a suggestion_id that is not a UUID' do
      stub = stub_request(:post, %r{#{suggestion_endpoint}/.*/discard})

      post dismiss_url, params: { suggestion_id: '../etc/passwd' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(stub).not_to have_been_requested
    end

    it 'discards the suggestion on LIA' do
      stub = stub_request(:post, "#{suggestion_endpoint}/#{suggestion_id}/discard")
             .with(headers: { 'Authorization' => 'Bearer segredo-de-teste' })
             .to_return(status: 200, body: { ok: true }.to_json, headers: { 'Content-Type' => 'application/json' })

      post dismiss_url, params: { suggestion_id: suggestion_id }, headers: agent.create_new_auth_token, as: :json

      expect(stub).to have_been_requested
      expect(response.parsed_body).to eq('ok' => true)
    end

    it 'answers ok false when LIA fails' do
      stub_request(:post, "#{suggestion_endpoint}/#{suggestion_id}/discard").to_return(status: 500)

      post dismiss_url, params: { suggestion_id: suggestion_id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq('ok' => false)
    end
  end
end
