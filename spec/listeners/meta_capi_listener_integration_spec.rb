require 'rails_helper'

# Prova a cadeia completa com o servico de entrada real, e nao com um factory: o payload cru
# da Cloud API entra, o Chatwoot grava o referral, e o listener despacha o Lead com o clique.
#
# E o que garante que o caminho do campo (messages[].referral.ctwa_clid) e a busca do clique
# na conversa continuam validos depois de um merge com o upstream.
describe MetaCapiListener, type: :service do
  let(:listener) { described_class.instance }
  let!(:whatsapp_channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false).tap do |channel|
      channel.update!(provider_config: channel.provider_config.merge('phone_number_id' => '1171321216059936'))
    end
  end
  let(:inbox) { whatsapp_channel.reload.inbox }
  let(:sender_number) { '5541999999999' }
  let(:ctwa_clid) { 'AfhcQdP2E4A8wWpeb1FqUzUi' }

  let(:params) do
    {
      phone_number: whatsapp_channel.phone_number,
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          value: {
            metadata: { phone_number_id: '1171321216059936' },
            contacts: [{ profile: { name: 'Fulana' }, wa_id: sender_number }],
            messages: [{
              from: sender_number,
              id: 'wamid.CTWA_TEST',
              timestamp: '1725480000',
              type: 'text',
              text: { body: 'Ola! Tenho interesse em alugar Bike' },
              referral: {
                source_type: 'ad', source_id: '52558118838064', source_url: 'https://fb.me/3TYpooaRT',
                headline: 'Esteira ou bike?', media_type: 'image', ctwa_clid: ctwa_clid
              }
            }]
          }
        }]
      }]
    }.with_indifferent_access
  end

  let(:config_json) do
    {
      '1171321216059936' => {
        'name' => 'Ponta Grossa', 'dataset_id' => '550018626702869', 'page_id' => '100000000000001',
        'purchase_labels' => ['alugou'], 'default_value' => 129.90
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

  after do
    Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| Redis::Alfred.delete(key) }
  end

  def ingest_ad_message
    Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: inbox, params: params).perform
    inbox.messages.last
  end

  it 'turns a real CTWA webhook into a LeadSubmitted carrying the click id' do
    allow(MetaCapi::SendEventJob).to receive(:perform_later)
    message = ingest_ad_message

    listener.message_created(Events::Base.new('message.created', Time.zone.now, message: message))

    expect(MetaCapi::SendEventJob).to have_received(:perform_later) do |args|
      expect(args[:phone_number_id]).to eq('1171321216059936')
      expect(args[:event][:event_name]).to eq('LeadSubmitted')
      expect(args[:event][:user_data][:ctwa_clid]).to eq(ctwa_clid)
      expect(args[:event][:user_data][:ph]).to eq(Digest::SHA256.hexdigest(sender_number))
    end
  end

  it 'recovers the click id from the conversation when the sale is later tagged' do
    message = ingest_ad_message
    conversation = message.conversation
    allow(MetaCapi::SendEventJob).to receive(:perform_later)

    listener.conversation_updated(
      Events::Base.new('conversation.updated', Time.zone.now,
                       conversation: conversation, changed_attributes: { 'label_list' => [[], ['alugou']] })
    )

    expect(MetaCapi::SendEventJob).to have_received(:perform_later) do |args|
      expect(args[:event][:event_name]).to eq('Purchase')
      expect(args[:event][:user_data][:ctwa_clid]).to eq(ctwa_clid)
      expect(args[:event][:custom_data]).to eq({ currency: 'BRL', value: 129.90 })
    end
  end
end
