class FollowUps::SyncConversationDueAtService
  pattr_initialize [:conversation!]

  def perform
    next_due = conversation.follow_up_runs.active.where.not(next_due_at: nil).minimum(:next_due_at)
    conversation.update_column(:follow_up_next_due_at, next_due)
  end
end
