require 'rails_helper'

RSpec.describe FollowUps::RetryService do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:run) do
    create(
      :follow_up_run,
      :failed,
      account: account,
      conversation: conversation,
      user: user
    )
  end
  let!(:failed_step) do
    create(
      :follow_up_step,
      :failed,
      follow_up_run: run,
      due_at: 1.hour.ago
    )
  end

  describe '#perform' do
    it 'requeues the failed step and reactivates the run' do
      clear_enqueued_jobs

      retried = described_class.new(run: run).perform

      expect(retried).to be_active
      expect(retried.context['error']).to be_nil
      expect(retried.context['retry_count']).to eq(1)
      expect(failed_step.reload).to be_scheduled
      expect(failed_step.error_message).to be_nil
      expect(enqueued_jobs.map { |job| job['job_class'] }).to include('FollowUps::ExecuteStepJob')
    end

    it 'raises when the run is not failed' do
      run.update!(status: :completed, context: {})

      expect do
        described_class.new(run: run).perform
      end.to raise_error(ArgumentError, /Only failed/)
    end
  end
end
