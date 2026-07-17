json.array! @follow_up_workflows do |workflow|
  json.partial! 'api/v1/models/follow_up_workflow', resource: workflow
end
