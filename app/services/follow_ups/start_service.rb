class FollowUps::StartService
  pattr_initialize [:conversation!, :user!, :workflow, :run_type, :due_at, :content, :template_params, :note, :cancel_on_incoming, :context]

  def perform
    FollowUpWorkflow.ensure_presets_for!(conversation.account)

    case resolved_run_type
    when 'remind_me'
      start_remind_me
    when 'message_if_no_reply'
      start_message_if_no_reply
    else
      start_workflow
    end
  end

  private

  def resolved_run_type
    run_type.presence || (workflow.present? ? 'workflow' : 'remind_me')
  end

  def start_remind_me
    create_run(
      run_type: 'remind_me',
      cancel_on_incoming: false,
      context: { 'note' => note.presence || content },
      steps: [
        {
          'type' => 'wait_then_act',
          'wait' => nil,
          'absolute_due_at' => parsed_due_at.iso8601,
          'conditions' => [],
          'on_fail' => 'skip',
          'actions' => [
            { 'action_name' => 'notify_assignee', 'action_params' => [] },
            { 'action_name' => 'add_private_note', 'action_params' => [reminder_note] }
          ]
        }
      ]
    )
  end

  def start_message_if_no_reply
    create_run(
      run_type: 'message_if_no_reply',
      cancel_on_incoming: cancel_on_incoming != false,
      context: {
        'content' => content,
        'template_params' => template_params || {},
        'note' => note
      },
      steps: [
        {
          'type' => 'wait_then_act',
          'wait' => nil,
          'absolute_due_at' => parsed_due_at.iso8601,
          'conditions' => [
            { 'attribute_key' => 'no_incoming_since_anchor', 'filter_operator' => 'equal_to', 'values' => [true] }
          ],
          'on_fail' => 'abort',
          'actions' => [
            {
              'action_name' => 'send_message',
              'action_params' => [content]
            }
          ]
        }
      ]
    )
  end

  def start_workflow
    raise ArgumentError, 'workflow is required' if workflow.blank?

    # One active run per workflow per conversation
    existing = conversation.follow_up_runs.active.find_by(follow_up_workflow_id: workflow.id)
    existing&.cancel!(reason: 'replaced_by_new_run')

    create_run(
      run_type: 'workflow',
      cancel_on_incoming: cancel_on_incoming != false,
      context: (context || {}).merge('workflow_name' => workflow.name),
      workflow: workflow,
      steps: workflow.steps
    )
  end

  def create_run(run_type:, cancel_on_incoming:, context:, steps:, workflow: nil)
    run = nil
    ActiveRecord::Base.transaction do
      run = conversation.follow_up_runs.create!(
        account: conversation.account,
        user: user,
        follow_up_workflow: workflow,
        run_type: run_type,
        status: :active,
        anchor_at: Time.current,
        cancel_on_incoming: cancel_on_incoming,
        context: context.merge('steps' => steps),
        current_step_index: 0
      )

      schedule_step!(run, steps, 0)
    end

    create_activity(run)
    run
  end

  def schedule_step!(run, steps, index)
    step_config = steps[index]
    raise ArgumentError, 'invalid step index' if step_config.blank?

    due_at = compute_due_at(step_config, run)
    step = run.follow_up_steps.create!(
      position: index,
      due_at: due_at,
      status: :scheduled,
      step_config: step_config
    )
    run.update!(current_step_index: index, next_due_at: due_at)
    step
  end

  def compute_due_at(step_config, run)
    if step_config['absolute_due_at'].present?
      return Time.zone.parse(step_config['absolute_due_at'].to_s)
    end

    wait = step_config['wait'] || { 'value' => 1, 'unit' => 'hours' }
    from = run.follow_up_steps.maximum(:due_at) || run.anchor_at
    FollowUps::WaitCalculator.new(
      conversation: conversation,
      wait_config: wait,
      from: from
    ).perform
  end

  def parsed_due_at
    time = due_at.is_a?(String) ? Time.zone.parse(due_at) : due_at
    raise ArgumentError, 'due_at is required' if time.blank?
    raise ArgumentError, 'due_at must be in the future' if time <= Time.current

    time
  end

  def reminder_note
    base = note.presence || content.presence || 'Follow-up reminder'
    "⏰ Follow-up due: #{base}"
  end

  def create_activity(run)
    content = I18n.t(
      'conversations.activity.follow_up.started',
      user_name: user.name,
      type: run.run_type.tr('_', ' ')
    )
    Conversations::ActivityMessageJob.perform_later(conversation, {
                                                      account_id: conversation.account_id,
                                                      inbox_id: conversation.inbox_id,
                                                      message_type: :activity,
                                                      content: content
                                                    })
  end
end
