class FollowUps::ExecuteStepService
  pattr_initialize [:step!]

  def perform
    return unless step.scheduled?

    run = step.follow_up_run
    return unless run.active?

    started_at = Time.current.iso8601
    step.update!(status: :running, result: { 'started_at' => started_at })
    conversation = run.conversation
    config = step.step_config.with_indifferent_access

    unless conditions_pass?(conversation, run, config)
      handle_condition_fail(run, config, started_at)
      return
    end

    handle_branch(run, config) if config[:branch].present?

    executor = FollowUps::ActionExecutor.new(
      conversation: conversation,
      run: run,
      actions: resolved_actions(config)
    )
    action_results = executor.perform

    step.update!(
      status: :done,
      error_message: nil,
      result: {
        'started_at' => started_at,
        'finished_at' => Time.current.iso8601,
        'executed_at' => Time.current.iso8601,
        'actions' => action_results
      }
    )
    enqueue_next_or_complete(run)
  rescue StandardError => e
    action_results = defined?(executor) ? Array(executor&.results) : []
    step.update!(
      status: :failed,
      error_message: e.message,
      result: {
        'started_at' => step.result['started_at'] || started_at,
        'finished_at' => Time.current.iso8601,
        'error_class' => e.class.name,
        'actions' => action_results
      }
    )
    run.mark_failed!(e.message)
    Rails.logger.error("[FollowUpStep] Failed ##{step.id}: #{e.class} #{e.message}")
  end

  private

  def conditions_pass?(conversation, run, config)
    FollowUps::ConditionEvaluator.new(
      conversation: conversation,
      run: run,
      conditions: config[:conditions] || []
    ).perform
  end

  def handle_condition_fail(run, config, started_at)
    on_fail = config[:on_fail].presence || 'abort'
    finished = {
      'started_at' => started_at,
      'finished_at' => Time.current.iso8601
    }

    if on_fail == 'skip'
      step.update!(status: :skipped, result: finished.merge('reason' => 'conditions_failed'))
      enqueue_next_or_complete(run)
    else
      step.update!(status: :skipped, result: finished.merge('reason' => 'conditions_failed_abort'))
      run.cancel!(reason: 'conditions_failed')
      create_activity(run, 'conversations.activity.follow_up.cancelled_condition')
    end
  end

  def handle_branch(run, config)
    branch = config[:branch].with_indifferent_access
    passed = FollowUps::ConditionEvaluator.new(
      conversation: run.conversation,
      run: run,
      conditions: branch[:if] || []
    ).perform

    goto = passed ? branch[:then_goto] : branch[:else_goto]
    run.context = run.context.merge('branch_goto' => goto)
    run.save!
  end

  def resolved_actions(config)
    actions = Array(config[:actions])
    if step.follow_up_run.run_type == 'message_if_no_reply'
      content = step.follow_up_run.context['content']
      actions = [{ 'action_name' => 'send_message', 'action_params' => [content] }] if content.present?
    end
    actions
  end

  def enqueue_next_or_complete(run)
    steps = run.workflow_steps
    branch_goto = run.context['branch_goto']
    next_index = if !branch_goto.nil?
                   run.context.delete('branch_goto')
                   run.save!
                   branch_goto
                 else
                   run.current_step_index + 1
                 end

    if next_index.nil? || next_index >= steps.length || next_index.negative?
      run.mark_completed!
      create_activity(run, 'conversations.activity.follow_up.completed')
      return
    end

    step_config = steps[next_index]
    due_at = compute_due_at(run, step_config)
    run.follow_up_steps.create!(
      position: next_index,
      due_at: due_at,
      status: :scheduled,
      step_config: step_config
    )
    run.update!(current_step_index: next_index, next_due_at: due_at)
  end

  def compute_due_at(run, step_config)
    if step_config['absolute_due_at'].present?
      return Time.zone.parse(step_config['absolute_due_at'].to_s)
    end

    wait = step_config['wait'] || { 'value' => 1, 'unit' => 'hours' }
    FollowUps::WaitCalculator.new(
      conversation: run.conversation,
      wait_config: wait,
      from: Time.current
    ).perform
  end

  def create_activity(run, i18n_key)
    Conversations::ActivityMessageJob.perform_later(run.conversation, {
                                                      account_id: run.account_id,
                                                      inbox_id: run.conversation.inbox_id,
                                                      message_type: :activity,
                                                      content: I18n.t(i18n_key, user_name: run.user.name, type: run.run_type.tr('_', ' '))
                                                    })
  end
end
