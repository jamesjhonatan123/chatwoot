class FollowUps::ActionExecutor
  pattr_initialize [:conversation!, :run!, :actions!]

  attr_reader :results

  def perform
    @results = []
    service = FollowUps::ActionService.new(conversation, run)

    Array(actions).each do |action|
      action = action.with_indifferent_access
      next if action[:action_name].blank?

      started_at = Time.current.iso8601
      begin
        service.public_send(action[:action_name], action[:action_params] || [])
        @results << {
          'action_name' => action[:action_name],
          'status' => 'done',
          'started_at' => started_at,
          'finished_at' => Time.current.iso8601
        }
      rescue StandardError => e
        @results << {
          'action_name' => action[:action_name],
          'status' => 'failed',
          'error' => e.message,
          'error_class' => e.class.name,
          'started_at' => started_at,
          'finished_at' => Time.current.iso8601
        }
        raise
      end
    end

    @results
  end
end
