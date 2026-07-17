require 'rails_helper'

RSpec.describe MessageContentPresenter do
  let(:conversation) { create(:conversation) }
  let(:message) { create(:message, conversation: conversation, content_type: content_type, content: content) }
  let(:presenter) { described_class.new(message) }

  describe '#outgoing_content' do
    context 'when message is not input_csat' do
      let(:content_type) { 'text' }
      let(:content) { 'Regular message' }

      it 'returns content transformed for channel (HTML for WebWidget)' do
        expect(presenter.outgoing_content).to eq("<p>Regular message</p>\n")
      end
    end

    context 'when message is input_csat and inbox is web widget' do
      let(:content_type) { 'input_csat' }
      let(:content) { 'Rate your experience' }

      before do
        allow(message.inbox).to receive(:web_widget?).and_return(true)
      end

      it 'returns content without survey URL (HTML for WebWidget)' do
        expect(presenter.outgoing_content).to eq("<p>Rate your experience</p>\n")
      end
    end

    context 'when message is input_csat and inbox is not web widget' do
      let(:content_type) { 'input_csat' }
      let(:content) { 'Rate your experience' }

      before do
        allow(message.inbox).to receive(:web_widget?).and_return(false)
      end

      it 'returns I18n default message when no CSAT config and dynamically generates survey URL (HTML format)' do
        with_modified_env 'FRONTEND_URL' => 'https://app.chatwoot.com' do
          expected_url = "https://app.chatwoot.com/survey/responses/#{conversation.uuid}"
          expect(presenter.outgoing_content).to include(expected_url)
          expect(presenter.outgoing_content).to include('<p>')
        end
      end

      it 'returns CSAT config message when config exists and dynamically generates survey URL (HTML format)' do
        with_modified_env 'FRONTEND_URL' => 'https://app.chatwoot.com' do
          allow(message.inbox).to receive(:csat_config).and_return({ 'message' => 'Custom CSAT message' })
          expected_url = "https://app.chatwoot.com/survey/responses/#{conversation.uuid}"
          expected_content = "<p>Custom CSAT message #{expected_url}</p>\n"
          expect(presenter.outgoing_content).to eq(expected_content)
        end
      end
    end

    context 'when WhatsApp inbox has sign_with_agent_name enabled' do
      let(:account) { create(:account) }
      let(:agent) { create(:user, account: account, name: 'Jane Doe', display_name: 'Jane') }
      let(:channel) do
        create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false)
      end
      let(:inbox) { channel.inbox.tap { |record| record.update!(sign_with_agent_name: true) } }
      let(:conversation) { create(:conversation, account: account, inbox: inbox) }
      let(:content_type) { 'text' }
      let(:content) { 'Hello customer' }
      let(:message) do
        create(
          :message,
          account: account,
          inbox: inbox,
          conversation: conversation,
          message_type: :outgoing,
          private: false,
          sender: agent,
          content_type: content_type,
          content: content
        )
      end

      it 'prepends the agent name in WhatsApp bold format' do
        expect(presenter.outgoing_content).to eq("*Jane*:\nHello customer")
      end

      it 'does not sign private notes' do
        message.update!(private: true)
        expect(presenter.outgoing_content).to eq('Hello customer')
      end

      it 'does not sign template messages' do
        message.update!(
          additional_attributes: {
            'template_params' => { 'name' => 'hello_world', 'language' => 'en' }
          }
        )
        expect(presenter.outgoing_content).to eq('Hello customer')
      end
    end
  end

  describe '#webhook_content' do
    context 'when message is not input_csat' do
      let(:content_type) { 'text' }
      let(:content) { 'Regular **bold** message' }

      it 'returns raw content without markdown rendering' do
        expect(presenter.webhook_content).to eq('Regular **bold** message')
      end

      it 'strips CommonMark hard-break backslashes before newlines' do
        message.update!(content: "First\\\nSecond\\\nThird\\\nFourth")
        expect(presenter.webhook_content).to eq("First\nSecond\nThird\nFourth")
      end

      it 'preserves backslashes that are not followed by a newline' do
        message.update!(content: "path\\to\\file\\\nNext line")
        expect(presenter.webhook_content).to eq("path\\to\\file\nNext line")
      end

      it 'handles carriage return and newline pairs' do
        message.update!(content: "Line one\\\r\nLine two\\\r\nLine three")
        expect(presenter.webhook_content).to eq("Line one\nLine two\nLine three")
      end

      it 'preserves normal newlines and only strips hard-break newlines' do
        message.update!(content: "line one\\\nline two\n\nline three")
        expect(presenter.webhook_content).to eq("line one\nline two\n\nline three")
      end
    end

    context 'when message is input_csat and inbox is not web widget' do
      let(:content_type) { 'input_csat' }
      let(:content) { 'Rate your experience' }

      before do
        allow(message.inbox).to receive(:web_widget?).and_return(false)
      end

      it 'includes CSAT survey URL without markdown rendering' do
        with_modified_env 'FRONTEND_URL' => 'https://app.chatwoot.com' do
          expected_url = "https://app.chatwoot.com/survey/responses/#{conversation.uuid}"
          expect(presenter.webhook_content).to include(expected_url)
          expect(presenter.webhook_content).not_to include('<p>')
        end
      end
    end
  end

  describe 'delegation' do
    let(:content_type) { 'text' }
    let(:content) { 'Test message' }

    it 'delegates model methods to the wrapped message' do
      expect(presenter.content).to eq('Test message')
      expect(presenter.content_type).to eq('text')
      expect(presenter.conversation).to eq(conversation)
    end
  end
end
