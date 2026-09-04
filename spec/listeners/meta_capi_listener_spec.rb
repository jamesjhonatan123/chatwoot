require 'rails_helper'

describe MetaCapiListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  # O factory de whatsapp_cloud sobrescreve o provider_config com valores fixos no
  # before(:create), entao o phone_number_id da praca e aplicado depois.
  let!(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              validate_provider_config: false, sync_templates: false).tap do |whatsapp|
      whatsapp.update!(provider_config: whatsapp.provider_config.merge('phone_number_id' => '1171321216059936'))
    end
  end
  let!(:inbox) { channel.reload.inbox }
  let!(:contact) { create(:contact, account: account, phone_number: '+5541999999999') }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  let(:ctwa_clid) { 'AfhcQdP2E4A8wWpeb1FqUzUi' }
  let(:referral_attributes) do
    { 'referral' => { 'source_type' => 'ad', 'source_id' => '120210000000000', 'ctwa_clid' => ctwa_clid } }
  end
  let(:hashed_phone) { Digest::SHA256.hexdigest('5541999999999') }

  let(:config_json) do
    {
      '1171321216059936' => {
        'name' => 'Ponta Grossa',
        'dataset_id' => '550018626702869',
        'page_id' => '100000000000001',
        'purchase_labels' => ['alugou'],
        'default_value' => 129.90
      }
    }.to_json
  end

  around do |example|
    with_modified_env(META_CAPI_CONFIG: config_json, META_CAPI_ACCESS_TOKEN: 'capi-token') do
      MetaCapi::Config.reload!
      example.run
    end
    MetaCapi::Config.reload!
  end

  describe '#message_created' do
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       message_type: 'incoming', content_attributes: referral_attributes)
    end
    let(:event) { Events::Base.new('message.created', Time.zone.now, message: message) }

    it 'dispatches a Lead carrying the click id from the first message' do
      expect(MetaCapi::SendEventJob).to receive(:perform_later).with(
        phone_number_id: '1171321216059936',
        event: hash_including(
          event_name: 'Lead',
          event_id: "lead-#{message.id}",
          action_source: 'business_messaging',
          messaging_channel: 'whatsapp',
          user_data: { ctwa_clid: ctwa_clid, page_id: '100000000000001', ph: hashed_phone }
        )
      ).once

      listener.message_created(event)
    end

    it 'uses the message timestamp as the event time' do
      allow(MetaCapi::SendEventJob).to receive(:perform_later)
      listener.message_created(event)

      expect(MetaCapi::SendEventJob).to have_received(:perform_later) do |args|
        expect(args[:event][:event_time]).to eq(message.created_at.to_i)
      end
    end

    it 'sends the Lead without custom_data' do
      allow(MetaCapi::SendEventJob).to receive(:perform_later)
      listener.message_created(event)

      expect(MetaCapi::SendEventJob).to have_received(:perform_later) do |args|
        expect(args[:event]).not_to have_key(:custom_data)
      end
    end

    context 'when the message did not come from an ad' do
      let(:message) do
        create(:message, account: account, inbox: inbox, conversation: conversation, message_type: 'incoming')
      end

      it 'dispatches nothing' do
        expect(MetaCapi::SendEventJob).not_to receive(:perform_later)
        listener.message_created(event)
      end
    end

    context 'when the message is outgoing' do
      let(:message) do
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         message_type: 'outgoing', content_attributes: referral_attributes)
      end

      it 'dispatches nothing' do
        expect(MetaCapi::SendEventJob).not_to receive(:perform_later)
        listener.message_created(event)
      end
    end

    context 'when the inbox phone_number_id is not configured' do
      let(:config_json) { { '999999999999999' => { 'dataset_id' => '1', 'page_id' => '2' } }.to_json }

      it 'dispatches nothing' do
        expect(MetaCapi::SendEventJob).not_to receive(:perform_later)
        listener.message_created(event)
      end
    end

    context 'when the inbox is not a WhatsApp channel' do
      let(:inbox) { create(:inbox, account: account) }

      it 'dispatches nothing' do
        expect(MetaCapi::SendEventJob).not_to receive(:perform_later)
        listener.message_created(event)
      end
    end
  end

  describe '#conversation_updated' do
    let(:changed_attributes) { { 'label_list' => [[], ['alugou']] } }
    let(:event) do
      Events::Base.new('conversation.updated', Time.zone.now,
                       conversation: conversation, changed_attributes: changed_attributes)
    end

    before do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       message_type: 'incoming', content_attributes: referral_attributes)
    end

    it 'dispatches a Purchase tied to the original click' do
      expect(MetaCapi::SendEventJob).to receive(:perform_later).with(
        phone_number_id: '1171321216059936',
        event: hash_including(
          event_name: 'Purchase',
          event_id: "purchase-#{conversation.id}",
          action_source: 'business_messaging',
          user_data: { ctwa_clid: ctwa_clid, page_id: '100000000000001', ph: hashed_phone },
          custom_data: { currency: 'BRL', value: 129.90 }
        )
      ).once

      listener.conversation_updated(event)
    end

    it 'prefers the value from the conversation custom attribute' do
      conversation.update!(custom_attributes: { 'valor_aluguel' => 249.90 })
      allow(MetaCapi::SendEventJob).to receive(:perform_later)

      listener.conversation_updated(event)

      expect(MetaCapi::SendEventJob).to have_received(:perform_later) do |args|
        expect(args[:event][:custom_data]).to eq({ currency: 'BRL', value: 249.90 })
      end
    end

    it 'marks the conversation so the sale is not counted twice' do
      allow(MetaCapi::SendEventJob).to receive(:perform_later)

      listener.conversation_updated(event)
      listener.conversation_updated(event)

      expect(MetaCapi::SendEventJob).to have_received(:perform_later).once
      expect(conversation.reload.additional_attributes['meta_capi_purchase_sent_at']).to be_present
    end

    context 'when the applied label is not a closing one' do
      let(:changed_attributes) { { 'label_list' => [[], ['orcamento']] } }

      it 'dispatches nothing' do
        expect(MetaCapi::SendEventJob).not_to receive(:perform_later)
        listener.conversation_updated(event)
      end
    end

    context 'when the label was removed rather than added' do
      let(:changed_attributes) { { 'label_list' => [%w[alugou], []] } }

      it 'dispatches nothing' do
        expect(MetaCapi::SendEventJob).not_to receive(:perform_later)
        listener.conversation_updated(event)
      end
    end

    context 'when the change does not involve labels' do
      let(:changed_attributes) { { 'status' => %w[open resolved] } }

      it 'dispatches nothing' do
        expect(MetaCapi::SendEventJob).not_to receive(:perform_later)
        listener.conversation_updated(event)
      end
    end

    context 'when the conversation did not come from an ad' do
      before { conversation.messages.destroy_all }

      it 'dispatches nothing' do
        expect(MetaCapi::SendEventJob).not_to receive(:perform_later)
        listener.conversation_updated(event)
      end
    end
  end
end
