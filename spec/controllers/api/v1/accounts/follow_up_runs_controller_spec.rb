require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::FollowUpRuns', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:workflow) { create(:follow_up_workflow, account: account) }

  describe 'GET /api/v1/accounts/:account_id/follow_up_runs' do
    it 'returns execution history ordered by updated_at' do
      failed = create(
        :follow_up_run,
        :failed,
        account: account,
        conversation: conversation,
        user: agent,
        follow_up_workflow: workflow,
        updated_at: 1.hour.ago
      )
      completed = create(
        :follow_up_run,
        :completed,
        account: account,
        conversation: conversation,
        user: agent,
        follow_up_workflow: workflow,
        updated_at: Time.current
      )
      create(:follow_up_step, :failed, follow_up_run: failed)
      create(:follow_up_step, :done, follow_up_run: completed)

      get "/api/v1/accounts/#{account.id}/follow_up_runs",
          params: { history: true },
          headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.first['id']).to eq(completed.id)
      expect(body.map { |item| item['id'] }).to include(failed.id, completed.id)
      expect(body.first['conversation']['display_id']).to eq(conversation.display_id)
    end

    it 'filters history by status' do
      create(
        :follow_up_run,
        :failed,
        account: account,
        conversation: conversation,
        user: agent
      )
      create(
        :follow_up_run,
        :completed,
        account: account,
        conversation: conversation,
        user: agent
      )

      get "/api/v1/accounts/#{account.id}/follow_up_runs",
          params: { history: true, status: 'failed' },
          headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.length).to eq(1)
      expect(body.first['status']).to eq('failed')
      expect(body.first['error']).to eq('Something went wrong')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/follow_up_runs/:id/retry' do
    it 'retries a failed run' do
      run = create(
        :follow_up_run,
        :failed,
        account: account,
        conversation: conversation,
        user: agent
      )
      create(:follow_up_step, :failed, follow_up_run: run)
      clear_enqueued_jobs

      post "/api/v1/accounts/#{account.id}/follow_up_runs/#{run.id}/retry",
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['status']).to eq('active')
      expect(run.reload).to be_active
    end
  end
end
