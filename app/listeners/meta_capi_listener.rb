# Fecha o ciclo de atribuicao dos anuncios Click-to-WhatsApp (CTWA).
#
# O anuncio leva a pessoa para o WhatsApp e a conversa acontece aqui, entao a Meta so ve
# "iniciou conversa" e nunca "alugou" — o algoritmo otimiza no escuro. A Cloud API entrega
# o identificador do clique (ctwa_clid) no referral da primeira mensagem, que o Chatwoot ja
# guarda em message.content_attributes['referral']. Este listener devolve esse clique para a
# Meta como Lead (chegou a mensagem) e Purchase (o atendente etiquetou a conversa).
#
# Multi-praca: cada inbox e uma praca com a sua conta de anuncios, Pagina e (talvez) dataset
# proprio. A praca sai do phone_number_id do canal — ver MetaCapi::Config.
class MetaCapiListener < BaseListener
  # Marca na conversa que o Purchase ja foi despachado. Reaplicar a etiqueta nao pode
  # contar a venda duas vezes.
  PURCHASE_SENT_KEY = 'meta_capi_purchase_sent_at'.freeze

  def message_created(event)
    message, = extract_message_and_account(event)
    return unless message.incoming?

    ctwa_clid = ctwa_clid_from(message)
    return if ctwa_clid.blank?

    praca = praca_for(message.inbox)
    return if praca.blank?

    dispatch(praca, builder(praca, message.conversation, ctwa_clid).lead(message))
  end

  def conversation_updated(event)
    added = added_labels(event)
    return if added.empty?

    conversation, = extract_conversation_and_account(event)
    return if purchase_already_sent?(conversation)

    praca = praca_for(conversation.inbox)
    return if praca.blank? || !added.intersect?(praca.purchase_labels)

    referral_message = referral_message_for(conversation)
    return if referral_message.blank?

    purchase = builder(praca, conversation, ctwa_clid_from(referral_message))
               .purchase(custom_data: purchase_custom_data(praca, conversation))

    dispatch(praca, purchase)
    mark_purchase_sent(conversation)
  end

  private

  # previous_changes['label_list'] chega como [antes, depois]; so interessa o que entrou agora.
  def added_labels(event)
    changed = event.data[:changed_attributes]
    return [] if changed.blank?

    before, after = changed['label_list'] || changed[:label_list]
    return [] unless before.is_a?(Array) && after.is_a?(Array)

    (after - before).map { |label| label.to_s.downcase }
  end

  def praca_for(inbox)
    channel = inbox&.channel
    return unless channel.is_a?(Channel::Whatsapp)

    MetaCapi::Config.for_phone_number_id(channel.provider_config['phone_number_id'])
  end

  def ctwa_clid_from(message)
    message.content_attributes&.dig('referral', 'ctwa_clid').presence
  end

  # O proprio registro da mensagem e o armazenamento do clique: nao ha estado externo a
  # expirar entre o Lead e o Purchase.
  #
  # Message usa `store :content_attributes` sobre uma coluna json, entao o conteudo fica
  # gravado como JSON *dentro de uma string* JSON — os operadores -> e ->> do Postgres nao
  # alcancam o campo. O LIKE no texto cru reduz a poucas linhas e a confirmacao real e
  # feita em Ruby, sobre o hash ja desserializado.
  def referral_message_for(conversation)
    conversation.messages
                .where('content_attributes::text LIKE ?', '%ctwa_clid%')
                .order(:created_at)
                .find { |message| ctwa_clid_from(message).present? }
  end

  def builder(praca, conversation, ctwa_clid)
    MetaCapi::EventBuilder.new(praca: praca, conversation: conversation, ctwa_clid: ctwa_clid)
  end

  def purchase_custom_data(praca, conversation)
    value = conversation.custom_attributes&.dig(praca.value_attribute).presence || praca.default_value
    return if value.blank?

    { currency: 'BRL', value: value.to_f }
  end

  def purchase_already_sent?(conversation)
    conversation.additional_attributes&.dig(PURCHASE_SENT_KEY).present?
  end

  # Chave fora de CONVERSATION_UPDATED_ADDITIONAL_ATTRIBUTE_KEYS, entao esta escrita nao
  # redispara conversation_updated (ver Conversation#allowed_keys?).
  def mark_purchase_sent(conversation)
    attributes = conversation.additional_attributes || {}
    conversation.update!(additional_attributes: attributes.merge(PURCHASE_SENT_KEY => Time.current.iso8601))
  end

  def dispatch(praca, event)
    MetaCapi::SendEventJob.perform_later(phone_number_id: praca.phone_number_id, event: event)
  end
end
