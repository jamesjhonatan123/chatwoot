class MessageContentPresenter < SimpleDelegator
  def outgoing_content
    content = Messages::MarkdownRendererService.new(
      content_with_survey_link,
      conversation.inbox.channel_type,
      conversation.inbox.channel
    ).render

    prepend_agent_signature(content)
  end

  def webhook_content
    Messages::WebhookContentNormalizer.normalize(content_with_survey_link)
  end

  private

  def prepend_agent_signature(content)
    return content unless should_sign_with_agent_name?

    agent_name = signature_agent_name
    return content if agent_name.blank?

    signature_prefix = "*#{agent_name}*:"
    return content if content.to_s.start_with?(signature_prefix)

    body = content.to_s
    body.present? ? "#{signature_prefix}\n#{body}" : signature_prefix
  end

  # A caixa oficial e compartilhada: os atendentes assinam, a automacao nao.
  # Por isso a excecao e do REMETENTE, e nao da caixa nem do papel — desligar a
  # assinatura da caixa calaria a assinatura dos atendentes na mesma caixa, e
  # "administrador" tambem nao serve porque parte da equipe e administradora.
  def should_sign_with_agent_name?
    return false unless outgoing?
    return false if private?
    return false if signature_suppressed?
    return false unless inbox&.sign_with_agent_name?
    return false unless inbox.channel_type == 'Channel::Whatsapp'

    true
  end

  # Dois motivos independentes de nao assinar: mensagem de template (regra que
  # ja existia) e conta de automacao.
  def signature_suppressed?
    additional_attributes&.dig('template_params').present? || sender_skips_signature?
  end

  def sender_skips_signature?
    sender.present? && sender.try(:skip_agent_signature).present?
  end

  def signature_agent_name
    return if sender.blank?

    if sender.respond_to?(:available_name)
      sender.available_name.presence || sender.name
    else
      sender.try(:name)
    end
  end

  def content_with_survey_link
    if should_append_survey_link?
      survey_link = survey_url(conversation.uuid)
      custom_message = inbox.csat_config&.dig('message')
      custom_message.present? ? "#{custom_message} #{survey_link}" : I18n.t('conversations.survey.response', link: survey_link)
    else
      content
    end
  end

  def should_append_survey_link?
    input_csat? && !inbox.web_widget?
  end

  def survey_url(conversation_uuid)
    "#{ENV.fetch('FRONTEND_URL', nil)}/survey/responses/#{conversation_uuid}"
  end
end
