require 'rails_helper'

RSpec.describe 'LIA Suggestion Metrics API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:lia_url) { 'http://lia.test' }
  let(:metrics_endpoint) { "#{lia_url}/api/chatwoot/suggestion-metrics" }
  let(:text_key) { 'a' * 40 }
  let(:show_url) { "/api/v1/accounts/#{account.id}/lia_suggestion_metrics" }
  let(:release_url) { "/api/v1/accounts/#{account.id}/lia_suggestion_metrics/release" }

  around do |example|
    with_modified_env(LIA_API_URL: lia_url, LIA_ADMIN_API_TOKEN: 'segredo-de-teste') { example.run }
  end

  it 'forbids agents' do
    stub = stub_request(:get, /#{metrics_endpoint}/)

    get show_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:forbidden)
    expect(stub).not_to have_been_requested
  end

  it 'passes the LIA metrics through for administrators, scoped to the account and period' do
    body = { totals: { shown: 3, used: 1 }, rejected: [] }
    stub = stub_request(:get, metrics_endpoint)
           .with(query: { account_id: account.id.to_s, days: '30' }, headers: { 'X-Admin-Token' => 'segredo-de-teste' })
           .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })

    get show_url, params: { days: 30 }, headers: admin.create_new_auth_token

    expect(stub).to have_been_requested
    expect(response.parsed_body['totals']).to eq('shown' => 3, 'used' => 1)
  end

  it 'answers an error body when LIA fails' do
    stub_request(:get, /#{metrics_endpoint}/).to_return(status: 500)

    get show_url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('error' => 'unavailable')
  end

  it 'rejects an invalid text_key on release' do
    stub = stub_request(:post, %r{#{lia_url}/api/chatwoot/suggestion-blocklist/.*/release})

    post release_url, params: { text_key: '../x' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(stub).not_to have_been_requested
  end

  it 'releases a blocked text on LIA with who released it' do
    stub = stub_request(:post, "#{lia_url}/api/chatwoot/suggestion-blocklist/#{text_key}/release")
           .with(body: { by: admin.available_name }.to_json)
           .to_return(status: 200, body: { ok: true }.to_json, headers: { 'Content-Type' => 'application/json' })

    post release_url, params: { text_key: text_key }, headers: admin.create_new_auth_token, as: :json

    expect(stub).to have_been_requested
    expect(response.parsed_body).to eq('ok' => true)
  end
end
