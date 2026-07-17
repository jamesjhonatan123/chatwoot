require 'rails_helper'

RSpec.describe FollowUps::ExecuteStepService do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:run) do
    create(
      :follow_up_run,
      account: account,
      conversation: conversation,
      user: user,
      context: {
        'steps' => [
          {
            'type' => 'wait_then_act',
            'conditions' => [],
            'on_fail' => 'abort',
            'actions' => [
              { 'action_name' => 'add_private_note', 'action_params' => ['Hello from follow-up'] }
            ]
          }
        ]
      }
    )
  end
  let(:step) do
    create(
      :follow_up_step,
      follow_up_run: run,
      due_at: Time.current,
      step_config: run.context['steps'].first
    )
  end

  before do
    clear_enqueued_jobs
    allow(Conversations::ActivityMessageJob).to receive(:perform_later)
  end

  describe '#perform' do
    it 'executes actions, records timing, and completes the run' do
      expect do
        described_class.new(step: step).perform
      end.to change { conversation.messages.outgoing.where(private: true).count }.by(1)

      step.reload
      run.reload

      expect(step).to be_done
      expect(step.result['started_at']).to be_present
      expect(step.result['finished_at']).to be_present
      expect(step.result['actions'].first['status']).to eq('done')
      expect(run).to be_completed
    end

    it 'marks the step and run as failed without re-raising' do
      allow_any_instance_of(FollowUps::ActionService)
        .to receive(:add_private_note)
        .and_raise(StandardError, 'delivery failed')

      expect do
        described_class.new(step: step).perform
      end.not_to raise_error

      step.reload
      run.reload

      expect(step).to be_failed
      expect(step.error_message).to eq('delivery failed')
      expect(step.result['error_class']).to eq('StandardError')
      expect(step.result['actions'].first['status']).to eq('failed')
      expect(run).to be_failed
      expect(run.context['error']).to eq('delivery failed')
    end

    it 'cancels the run when conditions fail with on_fail abort' do
      step.update!(
        step_config: step.step_config.merge(
          'conditions' => [
            {
              'attribute_key' => 'status',
              'filter_operator' => 'equal_to',
              'values' => ['resolved']
            }
          ],
          'on_fail' => 'abort'
        )
      )

      described_class.new(step: step).perform

      expect(step.reload).to be_skipped
      expect(run.reload).to be_cancelled
      expect(run.context['cancel_reason']).to eq('conditions_failed')
    end
  end
end
