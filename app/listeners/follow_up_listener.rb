class FollowUpListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return if message.blank?
    return unless message.incoming?
    return if message.private?

    FollowUps::CancelOnIncomingService.new(conversation: message.conversation).perform
  end
end
