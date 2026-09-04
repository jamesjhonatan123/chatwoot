require 'rails_helper'

describe MetaCapi::SendEventJob do
  subject(:job) { described_class }

  let(:endpoint) { 'https://graph.facebook.com/v21.0/550018626702869/events' }
  let(:event) do
    {
      event_name: 'LeadSubmitted', event_id: 'lead-1', event_time: 1_725_480_000,
      action_source: 'business_messaging', messaging_channel: 'whatsapp',
      user_data: { ctwa_clid: 'AfhcQdP2E4A8wWpeb1FqUzUi', page_id: '1', ph: 'hash' }
    }
  end
  let(:config_json) do
    { '1171321216059936' => { 'name' => 'Ponta Grossa', 'dataset_id' => '550018626702869' } }.to_json
  end

  around do |example|
    with_modified_env(META_CAPI_CONFIG: config_json, META_CAPI_ACCESS_TOKEN: 'capi-token') do
      MetaCapi::Config.reload!
      example.run
    end
    MetaCapi::Config.reload!
  end

  it 'runs on the low queue' do
    expect(job.new.queue_name).to eq('low')
  end

  it 'posts the event to the praca dataset with bearer auth' do
    request = stub_request(:post, endpoint)
              .with(
                headers: { 'Authorization' => 'Bearer capi-token', 'Content-Type' => 'application/json' },
                body: { data: [event] }.to_json
              )
              .to_return(status: 200, body: { events_received: 1 }.to_json, headers: { 'Content-Type' => 'application/json' })

    job.perform_now(phone_number_id: '1171321216059936', event: event)

    expect(request).to have_been_requested
  end

  it 'does not call the Graph API when the praca is not configured' do
    job.perform_now(phone_number_id: '000', event: event)

    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  # perform direto, e nao perform_now: retry_on captura a excecao e reenfileira.
  it 'raises a retryable error on 5xx' do
    stub_request(:post, endpoint).to_return(status: 500, body: 'boom')

    expect { job.new.perform(phone_number_id: '1171321216059936', event: event) }
      .to raise_error(described_class::RetryableError)
  end

  it 'does not retry on 4xx, only logs the rejection' do
    stub_request(:post, endpoint).to_return(status: 400, body: { error: { message: 'Invalid parameter' } }.to_json)

    expect(Rails.logger).to receive(:error).with(/recusado/)
    expect { job.new.perform(phone_number_id: '1171321216059936', event: event) }.not_to raise_error
  end

  it 'reenqueues on a 5xx instead of losing the event' do
    stub_request(:post, endpoint).to_return(status: 500, body: 'boom')

    expect { job.perform_now(phone_number_id: '1171321216059936', event: event) }
      .to have_enqueued_job(described_class)
  end

  # O evento e montado com chaves simbolicas; a fila do Sidekiq passa por JSON.
  it 'keeps symbol keys through ActiveJob serialization' do
    serialized = ActiveJob::Arguments.serialize([{ phone_number_id: '1171321216059936', event: event }])
    deserialized = ActiveJob::Arguments.deserialize(serialized).first

    expect(deserialized[:event][:event_name]).to eq('LeadSubmitted')
    expect(deserialized[:event][:user_data][:ctwa_clid]).to eq('AfhcQdP2E4A8wWpeb1FqUzUi')
  end
end
