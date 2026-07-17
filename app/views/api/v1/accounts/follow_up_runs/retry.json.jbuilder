json.partial! 'api/v1/models/follow_up_run', formats: [:json], resource: @follow_up_run
json.conversation do
  json.id @follow_up_run.conversation.id
  json.display_id @follow_up_run.conversation.display_id
end
