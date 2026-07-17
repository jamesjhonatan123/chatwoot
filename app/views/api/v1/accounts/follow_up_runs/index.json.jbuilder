json.array! @follow_up_runs do |run|
  json.partial! 'api/v1/models/follow_up_run', formats: [:json], resource: run
  json.conversation do
    json.id run.conversation.id
    json.display_id run.conversation.display_id
  end
end
