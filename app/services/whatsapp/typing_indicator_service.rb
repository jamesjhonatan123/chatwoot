# Marca a mensagem do cliente como lida e mostra "digitando…" no WhatsApp dele (Cloud API).
#
# A Meta apaga o indicador quando a resposta sai ou depois de 25 s; quem volta a digitar
# depois de uma resposta precisa chamar de novo.
# https://developers.facebook.com/docs/whatsapp/cloud-api/typing-indicators/
#
# Falha só vai para o log: "digitando…" é enfeite, nunca pode travar a resposta.
class Whatsapp::TypingIndicatorService
  # O indicador entrou na Cloud API em abril de 2025; a v13.0 que o envio usa é anterior.
  API_VERSION = 'v23.0'.freeze
  TIMEOUT_SECONDS = 5

  def initialize(whatsapp_channel)
    @whatsapp_channel = whatsapp_channel
  end

  def perform(incoming_source_id)
    response = HTTParty.post(url, headers: headers, body: body(incoming_source_id).to_json, timeout: TIMEOUT_SECONDS)
    return true if response.success?

    Rails.logger.warn("[WHATSAPP] lida/digitando recusado (#{response.code}): #{response.body.to_s.truncate(300)}")
    false
  rescue StandardError => e
    Rails.logger.warn("[WHATSAPP] lida/digitando falhou: #{e.class}: #{e.message}")
    false
  end

  private

  def url
    base = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    "#{base}/#{API_VERSION}/#{@whatsapp_channel.provider_config['phone_number_id']}/messages"
  end

  def headers
    @whatsapp_channel.provider_service.api_headers
  end

  def body(incoming_source_id)
    {
      messaging_product: 'whatsapp',
      status: 'read',
      message_id: incoming_source_id,
      typing_indicator: { type: 'text' }
    }
  end
end
