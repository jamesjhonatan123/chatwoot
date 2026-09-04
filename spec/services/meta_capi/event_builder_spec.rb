require 'rails_helper'

describe MetaCapi::EventBuilder do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, phone_number: '+5541999999999') }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              validate_provider_config: false, sync_templates: false).tap do |whatsapp|
      whatsapp.update!(provider_config: whatsapp.provider_config.merge('business_account_id' => '935105712897141'))
    end
  end
  let(:conversation) { create(:conversation, account: account, contact: contact, inbox: channel.reload.inbox) }
  let(:message) { create(:message, account: account, inbox: conversation.inbox, conversation: conversation, message_type: 'incoming') }
  let(:praca) do
    MetaCapi::Config::Praca.new(
      phone_number_id: '1171321216059936', name: 'Ponta Grossa', dataset_id: '550018626702869',
      page_id: '100000000000001', access_token: 'token', purchase_labels: ['alugou'],
      value_attribute: 'valor_aluguel', default_value: nil
    )
  end
  let(:builder) { described_class.new(praca: praca, conversation: conversation, ctwa_clid: 'AfhcQdP2E4A8wWpeb1FqUzUi') }

  describe '#lead' do
    subject(:event) { builder.lead(message) }

    it 'uses business_messaging as the action source, never website' do
      expect(event[:action_source]).to eq('business_messaging')
      expect(event[:messaging_channel]).to eq('whatsapp')
    end

    it 'is named LeadSubmitted, the taxonomy business_messaging accepts' do
      expect(event[:event_name]).to eq('LeadSubmitted')
    end

    it 'carries the captured click id' do
      expect(event[:user_data][:ctwa_clid]).to eq('AfhcQdP2E4A8wWpeb1FqUzUi')
      expect(event[:user_data][:page_id]).to eq('100000000000001')
    end

    it 'omits the whatsapp account id when a page_id is configured' do
      expect(event[:user_data]).not_to have_key(:whatsapp_business_account_id)
    end

    context 'without a configured page_id' do
      let(:praca) do
        MetaCapi::Config::Praca.new(
          phone_number_id: '1171321216059936', name: 'Ponta Grossa', dataset_id: '550018626702869',
          page_id: nil, access_token: 'token', purchase_labels: ['alugou'],
          value_attribute: 'valor_aluguel', default_value: nil
        )
      end

      # A Meta exige um dos dois (subcode 2804116): sem page_id, a WABA da inbox e o fallback.
      it 'falls back to the whatsapp business account id of the inbox' do
        expect(event[:user_data][:whatsapp_business_account_id]).to eq('935105712897141')
        expect(event[:user_data]).not_to have_key(:page_id)
      end
    end

    it 'hashes the phone in E.164 without the plus sign' do
      expect(event[:user_data][:ph]).to eq(Digest::SHA256.hexdigest('5541999999999'))
    end

    it 'derives a stable event id from the message so retries deduplicate' do
      expect(event[:event_id]).to eq("lead-#{message.id}")
    end

    it 'uses the message timestamp in unix seconds' do
      expect(event[:event_time]).to eq(message.created_at.to_i)
    end

    it 'omits custom_data' do
      expect(event).not_to have_key(:custom_data)
    end

    context 'without a phone number on the contact' do
      let(:contact) { create(:contact, account: account, phone_number: nil) }

      it 'omits the hashed phone instead of sending an empty hash' do
        expect(event[:user_data]).not_to have_key(:ph)
      end
    end
  end

  describe '#purchase' do
    it 'derives a stable event id from the conversation' do
      expect(builder.purchase[:event_id]).to eq("purchase-#{conversation.id}")
    end

    it 'includes the rental value when given' do
      event = builder.purchase(custom_data: { currency: 'BRL', value: 129.90 })

      expect(event[:event_name]).to eq('Purchase')
      expect(event[:custom_data]).to eq({ currency: 'BRL', value: 129.90 })
    end

    it 'omits custom_data when there is no value' do
      expect(builder.purchase).not_to have_key(:custom_data)
    end
  end
end
