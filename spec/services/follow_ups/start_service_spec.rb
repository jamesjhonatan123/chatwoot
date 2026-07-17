require 'rails_helper'

RSpec.describe FollowUps::StartService do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:user) { create(:user, account: account, role: :agent) }

  before do
    allow(FollowUpWorkflow).to receive(:ensure_presets_for!)
  end

  describe '#perform' do
    it 'starts a remind_me run with a scheduled step' do
      run = described_class.new(
        conversation: conversation,
        user: user,
        run_type: 'remind_me',
        due_at: 2.hours.from_now,
        note: 'Call back'
      ).perform

      expect(run).to be_active
      expect(run.run_type).to eq('remind_me')
      expect(run.follow_up_steps.count).to eq(1)
      expect(run.follow_up_steps.first).to be_scheduled
      expect(run.next_due_at).to be_present
    end

    it 'starts a message_if_no_reply run with gate conditions' do
      run = described_class.new(
        conversation: conversation,
        user: user,
        run_type: 'message_if_no_reply',
        due_at: 2.hours.from_now,
        content: 'Still there?'
      ).perform

      expect(run.run_type).to eq('message_if_no_reply')
      expect(run.cancel_on_incoming).to be(true)
      expect(run.context['content']).to eq('Still there?')
      expect(run.follow_up_steps.first.step_config['conditions']).not_to be_empty
    end

    it 'starts a workflow run from the workflow steps' do
      workflow = create(:follow_up_workflow, account: account)

      run = described_class.new(
        conversation: conversation,
        user: user,
        workflow: workflow
      ).perform

      expect(run.run_type).to eq('workflow')
      expect(run.follow_up_workflow).to eq(workflow)
      expect(run.follow_up_steps.first.step_config['actions'].first['action_name']).to eq('add_private_note')
    end

    it 'replaces an existing active run for the same workflow' do
      workflow = create(:follow_up_workflow, account: account)
      existing = described_class.new(
        conversation: conversation,
        user: user,
        workflow: workflow
      ).perform

      replacement = described_class.new(
        conversation: conversation,
        user: user,
        workflow: workflow
      ).perform

      expect(existing.reload).to be_cancelled
      expect(replacement).to be_active
    end
  end
end
