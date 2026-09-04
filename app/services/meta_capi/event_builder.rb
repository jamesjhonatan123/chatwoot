# Monta os eventos da Conversions API para conversas originadas de anuncio Click-to-WhatsApp.
#
# A diferenca para os eventos de site (que o PixelYourSite ja manda para o mesmo dataset)
# esta no action_source: aqui e sempre "business_messaging", e o identificador do usuario e
# o ctwa_clid que veio no referral da primeira mensagem, nao o cookie fbp/fbc. Por isso os
# dois nao colidem no dataset.
#
# A identidade (praca + clique + telefone) e a mesma nos dois eventos, entao fica no
# construtor; o que muda entre Lead e Purchase e so o nome, o event_id e o valor.
class MetaCapi::EventBuilder
  ACTION_SOURCE = 'business_messaging'.freeze
  MESSAGING_CHANNEL = 'whatsapp'.freeze

  # Com action_source business_messaging a Meta usa outra taxonomia de eventos: "Lead" e
  # recusado com "tipo de evento invalido" (subcode 2804066). O nome aceito e LeadSubmitted.
  LEAD_EVENT = 'LeadSubmitted'.freeze
  PURCHASE_EVENT = 'Purchase'.freeze

  def initialize(praca:, conversation:, ctwa_clid:)
    @praca = praca
    @conversation = conversation
    @ctwa_clid = ctwa_clid
  end

  # O event_id sai do id da mensagem: uma reentrega do job manda o mesmo id e a Meta deduplica.
  def lead(message)
    build(LEAD_EVENT, "lead-#{message.id}", message.created_at)
  end

  # Idem, mas por conversa: a venda e uma so, mesmo que a etiqueta seja reaplicada.
  def purchase(custom_data: nil)
    build(PURCHASE_EVENT, "purchase-#{@conversation.id}", Time.current, custom_data)
  end

  private

  def build(event_name, event_id, event_time, custom_data = nil)
    event = {
      event_name: event_name,
      event_id: event_id,
      event_time: event_time.to_i,
      action_source: ACTION_SOURCE,
      messaging_channel: MESSAGING_CHANNEL,
      user_data: user_data
    }
    event[:custom_data] = custom_data if custom_data.present?
    event
  end

  # A Meta exige page_id OU whatsapp_business_account_id (subcode 2804116) — nao e opcional.
  # Qual dos dois depende de como o dataset foi criado: um dataset vinculado a WABA aceita o
  # whatsapp_business_account_id; o pixel do site so aceita o page_id. Por isso o page_id
  # configurado tem precedencia, e a WABA da inbox e o fallback.
  def user_data
    identity = if @praca.page_id.present?
                 { page_id: @praca.page_id }
               else
                 { whatsapp_business_account_id: whatsapp_business_account_id }
               end

    { ctwa_clid: @ctwa_clid, ph: hashed_phone }.merge(identity).compact
  end

  def whatsapp_business_account_id
    channel = @conversation&.inbox&.channel
    return unless channel.is_a?(Channel::Whatsapp)

    channel.provider_config['business_account_id'].presence
  end

  # A Meta exige E.164 sem o '+', sem espacos e sem pontuacao, hasheado em SHA-256.
  # O Chatwoot guarda o telefone com o '+' na frente, entao so os digitos sobrevivem.
  def hashed_phone
    digits = @conversation&.contact&.phone_number.to_s.gsub(/\D/, '')
    return if digits.blank?

    Digest::SHA256.hexdigest(digits)
  end
end
