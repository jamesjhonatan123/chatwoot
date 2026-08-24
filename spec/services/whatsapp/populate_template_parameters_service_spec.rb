require 'rails_helper'

describe Whatsapp::PopulateTemplateParametersService do
  let(:service) { described_class.new }

  describe '#normalize_url' do
    it 'normalizes URLs with spaces' do
      url_with_spaces = 'https://example.com/path with spaces'
      normalized = service.send(:normalize_url, url_with_spaces)

      expect(normalized).to eq('https://example.com/path%20with%20spaces')
    end

    it 'handles URLs with special characters' do
      url = 'https://example.com/path?query=test value'
      normalized = service.send(:normalize_url, url)

      expect(normalized).to include('https://example.com/path')
      expect(normalized).not_to include(' ')
    end

    it 'returns valid URLs unchanged' do
      url = 'https://example.com/valid-path'
      normalized = service.send(:normalize_url, url)

      expect(normalized).to eq(url)
    end
  end

  describe '#build_media_parameter' do
    context 'when URL contains spaces' do
      it 'normalizes the URL before building media parameter' do
        url_with_spaces = 'https://example.com/image with spaces.jpg'
        result = service.build_media_parameter(url_with_spaces, 'IMAGE')

        expect(result[:type]).to eq('image')
        expect(result[:image][:link]).to eq('https://example.com/image%20with%20spaces.jpg')
      end
    end

    context 'when URL contains special characters in query string' do
      it 'normalizes the URL correctly' do
        url = 'https://example.com/video.mp4?title=My Video'
        result = service.build_media_parameter(url, 'VIDEO', 'test_video')

        expect(result[:type]).to eq('video')
        expect(result[:video][:link]).not_to include(' ')
      end
    end

    context 'when URL is already valid' do
      it 'builds media parameter without changing URL' do
        url = 'https://example.com/document.pdf'
        result = service.build_media_parameter(url, 'DOCUMENT', 'test.pdf')

        expect(result[:type]).to eq('document')
        expect(result[:document][:link]).to eq(url)
        expect(result[:document][:filename]).to eq('test.pdf')
      end
    end

    context 'when URL is blank' do
      it 'returns nil' do
        result = service.build_media_parameter('', 'IMAGE')

        expect(result).to be_nil
      end
    end
  end

  describe '#build_button_parameter' do
    it 'builds coupon_code parameters for copy_code buttons' do
      result = service.build_button_parameter('type' => 'copy_code', 'parameter' => 'SAVE20')

      expect(result).to eq(type: 'coupon_code', coupon_code: 'SAVE20')
    end

    it 'builds payment_link action for Brazil payment_request buttons' do
      result = service.build_button_parameter(
        'type' => 'payment_request',
        'payment_setting' => {
          'type' => 'payment_link',
          'payment_link' => { 'uri' => 'https://loc.fit/pagamento/22327' }
        }
      )

      expect(result).to eq(
        type: 'action',
        action: {
          payment_request: {
            payment_setting: {
              type: 'payment_link',
              payment_link: { uri: 'https://loc.fit/pagamento/22327' }
            }
          }
        }
      )
    end

    it 'builds pix_dynamic_code action for Brazil payment_request buttons' do
      result = service.build_button_parameter(
        'type' => 'payment_request',
        'payment_setting' => {
          'type' => 'PIX_DYNAMIC_CODE',
          'pix_dynamic_code' => { 'code' => '00020101021226700014br.gov.bcb.pix' }
        }
      )

      expect(result.dig(:action, :payment_request, :payment_setting, :type)).to eq('pix_dynamic_code')
      expect(result.dig(:action, :payment_request, :payment_setting, :pix_dynamic_code, :code))
        .to eq('00020101021226700014br.gov.bcb.pix')
    end

    it 'builds boleto action for Brazil payment_request buttons' do
      result = service.build_button_parameter(
        'type' => 'payment_request',
        'payment_setting' => {
          'type' => 'boleto',
          'boleto' => { 'digitable_line' => '03399026944140000002628346101018898510000008848' }
        }
      )

      expect(result.dig(:action, :payment_request, :payment_setting, :type)).to eq('boleto')
      expect(result.dig(:action, :payment_request, :payment_setting, :boleto, :digitable_line))
        .to eq('03399026944140000002628346101018898510000008848')
    end

    it 'raises when payment_link uri is missing' do
      expect do
        service.build_button_parameter(
          'type' => 'payment_request',
          'payment_setting' => { 'type' => 'payment_link', 'payment_link' => { 'uri' => '' } }
        )
      end.to raise_error(ArgumentError, /payment_link.uri/)
    end
  end
end
