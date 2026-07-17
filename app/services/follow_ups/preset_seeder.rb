class FollowUps::PresetSeeder
  pattr_initialize [:account!]

  PRESETS = [
    {
      preset_key: 'post_sale',
      name: 'Post-sale check-in',
      description: 'Ask if everything is fine 24h after resolve, then escalate if no reply.',
      trigger_mode: 'both',
      steps: [
        {
          'type' => 'wait_then_act',
          'wait' => { 'value' => 24, 'unit' => 'hours', 'business_hours' => false },
          'conditions' => [{ 'attribute_key' => 'no_incoming_since_anchor', 'filter_operator' => 'equal_to', 'values' => [true] }],
          'on_fail' => 'abort',
          'actions' => [
            { 'action_name' => 'send_message', 'action_params' => ['Hi! Just checking in — is everything going well?'] }
          ]
        },
        {
          'type' => 'wait_then_act',
          'wait' => { 'value' => 48, 'unit' => 'hours', 'business_hours' => false },
          'conditions' => [{ 'attribute_key' => 'no_incoming_since_anchor', 'filter_operator' => 'equal_to', 'values' => [true] }],
          'on_fail' => 'abort',
          'actions' => [
            { 'action_name' => 'add_label', 'action_params' => ['churn_risk'] },
            { 'action_name' => 'notify_assignee', 'action_params' => [] },
            { 'action_name' => 'add_private_note', 'action_params' => ['Follow-up: customer did not reply to post-sale check-in.'] }
          ]
        }
      ]
    },
    {
      preset_key: 'cold_lead',
      name: 'Cold lead nurture',
      description: 'Nudge assignee, send template-friendly message, then resolve if silent.',
      trigger_mode: 'manual',
      steps: [
        {
          'type' => 'wait_then_act',
          'wait' => { 'value' => 4, 'unit' => 'hours', 'business_hours' => true },
          'conditions' => [{ 'attribute_key' => 'no_incoming_since_anchor', 'filter_operator' => 'equal_to', 'values' => [true] }],
          'on_fail' => 'abort',
          'actions' => [
            { 'action_name' => 'notify_assignee', 'action_params' => [] },
            { 'action_name' => 'add_private_note', 'action_params' => ['Follow-up reminder: lead has not replied in 4 business hours.'] }
          ]
        },
        {
          'type' => 'wait_then_act',
          'wait' => { 'value' => 24, 'unit' => 'hours', 'business_hours' => false },
          'conditions' => [{ 'attribute_key' => 'no_incoming_since_anchor', 'filter_operator' => 'equal_to', 'values' => [true] }],
          'on_fail' => 'abort',
          'actions' => [
            { 'action_name' => 'send_message', 'action_params' => ['Hi! Circling back in case my previous message got buried. Happy to help whenever you are ready.'] }
          ]
        },
        {
          'type' => 'wait_then_act',
          'wait' => { 'value' => 72, 'unit' => 'hours', 'business_hours' => false },
          'conditions' => [{ 'attribute_key' => 'no_incoming_since_anchor', 'filter_operator' => 'equal_to', 'values' => [true] }],
          'on_fail' => 'abort',
          'actions' => [
            { 'action_name' => 'add_private_note', 'action_params' => ['Auto-resolved after cold lead follow-up sequence.'] },
            { 'action_name' => 'resolve_conversation', 'action_params' => [] }
          ]
        }
      ]
    },
    {
      preset_key: 'pending_docs',
      name: 'Pending documents',
      description: 'Remind on D+1, D+3 and D+7 while waiting for documents.',
      trigger_mode: 'manual',
      steps: [
        {
          'type' => 'wait_then_act',
          'wait' => { 'value' => 1, 'unit' => 'days', 'business_hours' => false },
          'conditions' => [{ 'attribute_key' => 'no_incoming_since_anchor', 'filter_operator' => 'equal_to', 'values' => [true] }],
          'on_fail' => 'abort',
          'actions' => [
            { 'action_name' => 'send_message', 'action_params' => ['Friendly reminder: we are still waiting for the documents to proceed.'] }
          ]
        },
        {
          'type' => 'wait_then_act',
          'wait' => { 'value' => 2, 'unit' => 'days', 'business_hours' => false },
          'conditions' => [{ 'attribute_key' => 'no_incoming_since_anchor', 'filter_operator' => 'equal_to', 'values' => [true] }],
          'on_fail' => 'abort',
          'actions' => [
            { 'action_name' => 'send_message', 'action_params' => ['Second reminder about the pending documents. Let us know if you need help uploading them.'] }
          ]
        },
        {
          'type' => 'wait_then_act',
          'wait' => { 'value' => 4, 'unit' => 'days', 'business_hours' => false },
          'conditions' => [{ 'attribute_key' => 'no_incoming_since_anchor', 'filter_operator' => 'equal_to', 'values' => [true] }],
          'on_fail' => 'abort',
          'actions' => [
            { 'action_name' => 'send_message', 'action_params' => ['Final reminder regarding the pending documents. We will close this request soon if we do not hear back.'] },
            { 'action_name' => 'add_label', 'action_params' => ['docs_overdue'] },
            { 'action_name' => 'notify_assignee', 'action_params' => [] }
          ]
        }
      ]
    },
    {
      preset_key: 'promise_callback',
      name: 'Promised callback',
      description: 'Remind the assignee at a set delay with an optional draft note.',
      trigger_mode: 'manual',
      steps: [
        {
          'type' => 'wait_then_act',
          'wait' => { 'value' => 1, 'unit' => 'days', 'business_hours' => true },
          'conditions' => [],
          'on_fail' => 'skip',
          'actions' => [
            { 'action_name' => 'notify_assignee', 'action_params' => [] },
            { 'action_name' => 'add_private_note', 'action_params' => ['Callback promise due — follow up with the customer.'] }
          ]
        }
      ]
    }
  ].freeze

  def perform!
    PRESETS.each do |preset|
      workflow = account.follow_up_workflows.find_or_initialize_by(preset_key: preset[:preset_key])
      next if workflow.persisted?

      workflow.assign_attributes(
        name: preset[:name],
        description: preset[:description],
        trigger_mode: preset[:trigger_mode],
        steps: preset[:steps],
        system_preset: true,
        active: true
      )
      workflow.save!
    end
  end
end
