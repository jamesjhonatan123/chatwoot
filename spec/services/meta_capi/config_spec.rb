require 'rails_helper'

describe MetaCapi::Config do
  let(:config_json) do
    {
      '1171321216059936' => { 'name' => 'Ponta Grossa', 'dataset_id' => '550018626702869', 'page_id' => '1' },
      '2222222222222222' => { 'name' => 'Uberlandia', 'dataset_id' => '777', 'access_token' => 'token-proprio' }
    }.to_json
  end

  around do |example|
    with_modified_env(META_CAPI_CONFIG: config_json, META_CAPI_ACCESS_TOKEN: 'token-padrao') do
      described_class.reload!
      example.run
    end
    described_class.reload!
  end

  it 'resolves the praca by phone_number_id' do
    praca = described_class.for_phone_number_id('1171321216059936')

    expect(praca.name).to eq('Ponta Grossa')
    expect(praca.dataset_id).to eq('550018626702869')
    expect(praca.phone_number_id).to eq('1171321216059936')
  end

  it 'falls back to the global token' do
    expect(described_class.for_phone_number_id('1171321216059936').access_token).to eq('token-padrao')
  end

  it 'prefers the praca own token when present' do
    expect(described_class.for_phone_number_id('2222222222222222').access_token).to eq('token-proprio')
  end

  it 'applies the default closing label' do
    expect(described_class.for_phone_number_id('1171321216059936').purchase_labels).to eq(['alugou'])
  end

  it 'returns nil for an unknown number' do
    expect(described_class.for_phone_number_id('0000')).to be_nil
  end

  it 'returns nil for a blank phone_number_id' do
    expect(described_class.for_phone_number_id(nil)).to be_nil
  end

  context 'when the praca has no dataset' do
    let(:config_json) { { '1171321216059936' => { 'name' => 'Sem dataset' } }.to_json }

    it 'treats it as not configured' do
      expect(described_class.for_phone_number_id('1171321216059936')).to be_nil
    end
  end

  context 'with invalid JSON' do
    let(:config_json) { '{ isso nao e json' }

    it 'does not blow up the application' do
      expect(described_class.for_phone_number_id('1171321216059936')).to be_nil
      expect(described_class).not_to be_configured
    end
  end
end
