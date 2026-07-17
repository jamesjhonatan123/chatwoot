class FollowUps::RetryService
  pattr_initialize [:run!]

  def perform
    raise ArgumentError, 'Only failed follow-ups can be retried' unless run.failed?

    step = run.follow_up_steps.failed.order(:position).last
    raise ArgumentError, 'No failed step to retry' if step.blank?

    due_at = Time.current

    ActiveRecord::Base.transaction do
      step.update!(
        status: :scheduled,
        due_at: due_at,
        error_message: nil,
        result: { 'retried_at' => due_at.iso8601 }
      )

      context = run.context.except('error')
      context['retry_count'] = context.fetch('retry_count', 0).to_i + 1
      context['last_retried_at'] = due_at.iso8601

      run.update!(
        status: :active,
        next_due_at: due_at,
        current_step_index: step.position,
        context: context
      )
    end

    FollowUps::ExecuteStepJob.set(wait_until: due_at).perform_later(step.id)
    run.reload
  end
end
