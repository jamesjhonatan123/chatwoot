json.array! @follow_up_runs do |run|
  json.partial! 'api/v1/models/follow_up_run', resource: run
end
