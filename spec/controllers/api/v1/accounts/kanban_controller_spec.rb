require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Kanban', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let!(:label1) { create(:label, account: account, title: 'Label1') }
  let!(:label2) { create(:label, account: account, title: 'Label2') }
  let!(:conversation1) { create(:conversation, account: account, status: :resolved) }
  let!(:conversation2) { create(:conversation, account: account, status: :pending) }

  before do
    conversation1.add_labels(['Label1'])
    conversation2.add_labels(['Label2'])
  end

  describe 'GET /api/v1/accounts/:account_id/kanban' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/kanban"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'returns kanban data grouped by labels including resolved and pending conversations' do
        get "/api/v1/accounts/#{account.id}/kanban", headers: user.create_new_auth_token

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)

        expect(json_response['data'].keys).to include('label1', 'label2')
        expect(json_response['data']['label1'].length).to eq(1)
        expect(json_response['data']['label1'][0]['id']).to eq(conversation1.display_id)
        expect(json_response['data']['label2'].length).to eq(1)
        expect(json_response['data']['label2'][0]['id']).to eq(conversation2.display_id)
      end
    end
  end
end
