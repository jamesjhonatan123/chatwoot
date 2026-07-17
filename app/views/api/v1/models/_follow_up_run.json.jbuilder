json.id resource.id
json.run_type resource.run_type
json.status resource.status
json.anchor_at resource.anchor_at.to_i
json.next_due_at resource.next_due_at&.to_i
json.current_step_index resource.current_step_index
json.cancel_on_incoming resource.cancel_on_incoming
json.context resource.context
json.error resource.context['error']
json.cancel_reason resource.context['cancel_reason']
json.retry_count resource.context['retry_count'].to_i
json.conversation_id resource.conversation_id
json.follow_up_workflow_id resource.follow_up_workflow_id
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i

if resource.follow_up_workflow
  json.workflow do
    json.id resource.follow_up_workflow.id
    json.name resource.follow_up_workflow.name
    json.preset_key resource.follow_up_workflow.preset_key
  end
end

json.user do
  json.id resource.user.id
  json.name resource.user.name
  json.available_name resource.user.available_name
  json.avatar_url resource.user.avatar_url
end

json.steps resource.follow_up_steps.order(:position) do |step|
  json.id step.id
  json.position step.position
  json.due_at step.due_at.to_i
  json.status step.status
  json.step_config step.step_config
  json.result step.result
  json.error_message step.error_message
  json.started_at step.result['started_at']
  json.finished_at step.result['finished_at']
  json.actions step.result['actions'] || []
end
