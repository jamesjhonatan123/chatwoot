# Leva o "digitando…" do Chatwoot ao WhatsApp do cliente (API oficial da Meta).
#
# O Chatwoot só avisava o painel e os webhooks: o cliente nunca via "digitando…" nem os
# tiques azuis, fosse a LIA ou a atendente respondendo. Na Cloud API uma chamada só faz as
# duas coisas (status "read" + typing_indicator) e o indicador some quando a resposta sai
# ou depois de 25 s.
#
# Regras:
# - nota interna não aparece para o cliente;
# - só inbox WhatsApp da API oficial, com mensagem do cliente nas últimas 24 h (fora dessa
#   janela a atendente só pode mandar template, e o "digitando…" não tem resposta a anunciar);
# - uma chamada por resposta: repetir o "digitando…" antes de a resposta sair não chama de
#   novo por THROTTLE_SECONDS; chama outra vez depois que uma mensagem sai para o cliente ou
#   quando chega mensagem nova do cliente (senão ela ficaria sem "lida").
class WhatsappTypingListener < BaseListener
  THROTTLE_SECONDS = 20
  MAX_INCOMING_AGE = 24.hours

  def conversation_typing_on(event)
    return if ActiveModel::Type::Boolean.new.cast(event.data[:is_private])

    conversation = event.data[:conversation]
    channel = cloud_channel(conversation)
    return if channel.blank?

    incoming = last_incoming_message(conversation)
    return if incoming.blank?
    return unless first_call_for_this_reply?(conversation, incoming)

    Whatsapp::TypingIndicatorService.new(channel).perform(incoming.source_id)
  end

  private

  def cloud_channel(conversation)
    channel = conversation&.inbox&.channel
    channel if channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'
  end

  def last_incoming_message(conversation)
    conversation.messages.incoming
                .where.not(source_id: [nil, ''])
                .where('created_at >= ?', MAX_INCOMING_AGE.ago)
                .reorder(created_at: :desc).first
  end

  def first_call_for_this_reply?(conversation, incoming)
    # Só o que o cliente vê conta como resposta: nota interna não, template sim.
    last_reply_id = conversation.messages.chat.where(message_type: %i[outgoing template]).maximum(:id)
    key = "whatsapp_typing:#{conversation.id}:#{incoming.id}:#{last_reply_id || 0}"
    Redis::Alfred.set(key, 1, nx: true, ex: THROTTLE_SECONDS)
  end
end
