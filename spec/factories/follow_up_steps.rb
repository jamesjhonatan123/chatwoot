FactoryBot.define do
  factory :follow_up_step do
    follow_up_run
    position { 0 }
    due_at { 1.hour.from_now }
    status { :scheduled }
    step_config do
      {
        'type' => 'wait_then_act',
        'wait' => { 'value' => 1, 'unit' => 'hours', 'business_hours' => false },
        'conditions' => [],
        'on_fail' => 'abort',
        'actions' => [
          { 'action_name' => 'add_private_note', 'action_params' => ['Step note'] }
        ]
      }
    end
    result { {} }

    trait :failed do
      status { :failed }
      error_message { 'Boom' }
      result do
        {
          'started_at' => 1.minute.ago.iso8601,
          'finished_at' => Time.current.iso8601,
          'error_class' => 'RuntimeError',
          'actions' => [
            {
              'action_name' => 'add_private_note',
              'status' => 'failed',
              'error' => 'Boom'
            }
          ]
        }
      end
    end

    trait :done do
      status { :done }
      result do
        {
          'started_at' => 1.minute.ago.iso8601,
          'finished_at' => Time.current.iso8601,
          'executed_at' => Time.current.iso8601,
          'actions' => [
            { 'action_name' => 'add_private_note', 'status' => 'done' }
          ]
        }
      end
    end
  end
end
