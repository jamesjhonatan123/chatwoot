class FollowUps::CancelOnIncomingService
  pattr_initialize [:conversation!]

  def perform
    conversation.follow_up_runs.active.where(cancel_on_incoming: true).find_each do |run|
      run.cancel!(reason: 'customer_replied')
      Conversations::ActivityMessageJob.perform_later(conversation, {
                                                       account_id: conversation.account_id,
                                                       inbox_id: conversation.inbox_id,
                                                       message_type: :activity,
                                                       content: I18n.t(
                                                         'conversations.activity.follow_up.cancelled_reply',
                                                         type: run.run_type.tr('_', ' ')
                                                       )
                                                     })
    end
  end
end
