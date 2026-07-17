require 'rails_helper'

RSpec.describe FollowUps::ActionService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assignee) { create(:user, account: account, role: :agent) }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, assignee: assignee)
  end
  let(:user) { create(:user, account: account, role: :agent) }
  let(:run) do
    create(
      :follow_up_run,
      account: account,
      conversation: conversation,
      user: user,
      context: {}
    )
  end
  let(:service) { described_class.new(conversation, run) }

  describe '#send_message' do
    it 'sends a plain text message' do
      expect do
        service.send_message(['Hello there'])
      end.to change { conversation.messages.outgoing.where(private: false).count }.by(1)

      expect(conversation.messages.outgoing.last.content).to eq('Hello there')
    end

    it 'sends a template-backed message when template_params are present' do
      payload = {
        'message' => 'Rendered template body',
        'template_params' => {
          'name' => 'hello_world',
          'language' => 'en',
          'category' => 'UTILITY',
          'processed_params' => { 'body' => { '1' => 'Alex' } }
        }
      }

      expect do
        service.send_message([payload])
      end.to change { conversation.messages.outgoing.count }.by(1)

      message = conversation.messages.outgoing.last
      expect(message.content).to eq('Rendered template body')
      expect(message.additional_attributes['template_params']['name']).to eq('hello_world')
    end
  end

  describe '#notify_assignee' do
    before do
      create(:inbox_member, inbox: inbox, user: assignee)
    end

    it 'creates a follow_up_due notification for the assignee' do
      expect do
        service.notify_assignee([])
      end.to change(Notification, :count).by(1)

      notification = Notification.last
      expect(notification.notification_type).to eq('follow_up_due')
      expect(notification.user).to eq(assignee)
    end
  end
end
