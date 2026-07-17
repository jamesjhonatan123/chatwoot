class FollowUps::AnalyticsService
  pattr_initialize [:account!]

  def perform
    runs = account.follow_up_runs
    steps = FollowUpStep.joins(:follow_up_run).where(follow_up_runs: { account_id: account.id })

    {
      totals: {
        runs: runs.count,
        active: runs.active.count,
        completed: runs.completed.count,
        cancelled: runs.cancelled.count,
        failed: runs.failed.count
      },
      steps: {
        done: steps.done.count,
        skipped: steps.skipped.count,
        failed: steps.failed.count,
        cancelled: steps.cancelled.count
      },
      by_workflow: runs.joins(:follow_up_workflow)
                       .group('follow_up_workflows.name')
                       .count,
      completion_rate: completion_rate(runs),
      reply_cancel_rate: reply_cancel_rate(runs)
    }
  end

  private

  def completion_rate(runs)
    total = runs.where(status: %i[completed cancelled failed]).count
    return 0 if total.zero?

    ((runs.completed.count.to_f / total) * 100).round(1)
  end

  def reply_cancel_rate(runs)
    cancelled = runs.cancelled.count
    return 0 if cancelled.zero?

    reply_cancelled = runs.cancelled.where("context->>'cancel_reason' = ?", 'customer_replied').count
    ((reply_cancelled.to_f / cancelled) * 100).round(1)
  end
end
