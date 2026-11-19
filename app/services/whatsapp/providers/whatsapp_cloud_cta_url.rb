# Botão de link (interactive cta_url) da Cloud API.
#
# Quem cria a mensagem deixa o link no texto e pede o botão em content_attributes:
#   { cta_url: { url: 'https://...', display_text: 'Começar a treinar' } }
# O texto da conversa no Chatwoot continua com o link (a equipe vê o que foi mandado). Para o
# cliente, o link sai do corpo e vira o botão. Qualquer coisa fora do formato, ou a Meta recusando
# o botão, manda o texto de sempre: o cliente nunca fica sem o link.
module Whatsapp::Providers::WhatsappCloudCtaUrl
  # Limites da Cloud API para o botão: rótulo até 20 caracteres, corpo até 1024.
  CTA_DISPLAY_TEXT_LIMIT = 20
  CTA_BODY_LIMIT = 1024

  private

  def cta_url_button(message)
    url, label = cta_url_request(message)
    return if url.blank?

    content = message.outgoing_content.to_s
    return unless content.include?(url)

    body = cta_body_without(content, url)
    return if body.blank? || body.length > CTA_BODY_LIMIT

    { url: url, display_text: label, body: body }
  end

  def cta_url_request(message)
    cta = message.content_attributes.with_indifferent_access[:cta_url]
    return unless cta.is_a?(Hash)

    url = cta[:url].to_s.strip
    label = cta[:display_text].to_s.strip
    return unless url.match?(%r{\Ahttps://\S+\z}i) && label.present? && label.length <= CTA_DISPLAY_TEXT_LIMIT

    [url, label]
  end

  # Tira o link (e a seta que o apontava) e as linhas que ficaram vazias no lugar dele.
  def cta_body_without(content, url)
    content.gsub(/(?:👉\s*)?#{Regexp.escape(url)}/, '')
           .gsub(/[ \t]+$/, '')
           .gsub(/\n{3,}/, "\n\n")
           .strip
  end

  def send_cta_url_message(phone_number, message, button)
    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        **recipient_params(phone_number),
        type: 'interactive',
        interactive: {
          type: 'cta_url',
          body: { text: button[:body] },
          action: { name: 'cta_url', parameters: { display_text: button[:display_text], url: button[:url] } }
        }
      }.to_json
    )
    return process_response(response, message) if response.success? && response.parsed_response['error'].blank?

    Rails.logger.warn("[WHATSAPP_CTA_URL] botão recusado message_id=#{message.id} http_status=#{response.code} " \
                      "meta_error=#{error_message(response)}; enviando como texto")
    send_text_message(phone_number, message)
  end
end
