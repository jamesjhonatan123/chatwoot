require 'rails_helper'

RSpec.describe Captain::FollowUpWorkflowGeneratorService do
  let(:account) { create(:account) }
  let(:service) do
    described_class.new(
      account: account,
      prompt: 'Remind the customer after 1 day if documents are missing',
      language: 'en'
    )
  end

  before do
    allow(account).to receive(:feature_enabled?).and_call_original
    allow(account).to receive(:feature_enabled?).with('captain_tasks').and_return(true)
    create(:label, account: account, title: 'docs_overdue')
  end

  describe '#perform' do
    it 'returns a sanitized workflow from the LLM JSON response' do
      llm_payload = {
        'name' => 'Pending docs',
        'description' => 'Remind about documents',
        'trigger_mode' => 'manual',
        'steps' => [
          {
            'type' => 'wait_then_act',
            'wait' => { 'value' => 1, 'unit' => 'days', 'business_hours' => false },
            'conditions' => [],
            'on_fail' => 'abort',
            'actions' => [
              {
                'action_name' => 'send_message',
                'action_params' => ['Please send the documents']
              },
              {
                'action_name' => 'add_label',
                'action_params' => ['docs_overdue']
              }
            ]
          }
        ]
      }

      allow(service).to receive(:make_api_call).and_return(message: llm_payload.to_json)

      result = service.perform

      expect(result[:error]).to be_nil
      expect(result[:workflow]['name']).to eq('Pending docs')
      expect(result[:workflow]['steps'].length).to eq(1)
      expect(result[:workflow]['steps'].first['actions'].map { |a| a['action_name'] })
        .to contain_exactly('send_message', 'add_label')
    end

    it 'accepts a whatsapp template action when the template exists' do
      channel = create(
        :channel_whatsapp,
        account: account,
        sync_templates: false,
        validate_provider_config: false
      )
      inbox = channel.inbox
      channel.update!(
        message_templates: [
          {
            'name' => 'docs_reminder',
            'language' => 'en',
            'category' => 'UTILITY',
            'status' => 'APPROVED',
            'namespace' => 'ns',
            'components' => [
              { 'type' => 'BODY', 'text' => 'Hi {{1}}, please send the docs.' }
            ]
          }
        ]
      )

      llm_payload = {
        'name' => 'Docs template flow',
        'description' => 'Use official template',
        'trigger_mode' => 'manual',
        'steps' => [
          {
            'wait' => { 'value' => 1, 'unit' => 'days' },
            'on_fail' => 'abort',
            'actions' => [
              {
                'action_name' => 'send_message',
                'action_params' => [
                  {
                    'type' => 'whatsapp_template',
                    'inbox_id' => inbox.id,
                    'name' => 'docs_reminder',
                    'language' => 'en',
                    'processed_params' => { 'body' => { '1' => 'Alex' } }
                  }
                ]
              }
            ]
          }
        ]
      }

      allow(service).to receive(:make_api_call).and_return(message: llm_payload.to_json)

      result = service.perform
      action = result[:workflow]['steps'].first['actions'].first

      expect(action['action_name']).to eq('send_message')
      expect(action['action_params'].first['message']).to eq('Hi Alex, please send the docs.')
      expect(action['action_params'].first['template_params']['name']).to eq('docs_reminder')
    end

    it 'returns an error when prompt is blank' do
      result = described_class.new(account: account, prompt: '   ').perform
      expect(result[:error]).to eq('Prompt is required')
    end
  end
end
