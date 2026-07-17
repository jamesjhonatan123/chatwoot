class SendScheduledMessageJob < ApplicationJob
  queue_as :high

  def perform(scheduled_message_id)
    scheduled_message = ScheduledMessage.find_by(id: scheduled_message_id)
    return if scheduled_message.blank?
    return unless scheduled_message.pending?

    scheduled_message.deliver!
  end
end
