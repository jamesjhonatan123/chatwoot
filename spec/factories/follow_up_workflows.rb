FactoryBot.define do
  factory :follow_up_workflow do
    account
    name { 'Test follow-up workflow' }
    description { 'Used in specs' }
    trigger_mode { 'manual' }
    active { true }
    system_preset { false }
    steps do
      [
        {
          'type' => 'wait_then_act',
          'wait' => { 'value' => 1, 'unit' => 'hours', 'business_hours' => false },
          'conditions' => [],
          'on_fail' => 'abort',
          'actions' => [
            { 'action_name' => 'add_private_note', 'action_params' => ['Follow-up note'] }
          ],
          'branch' => nil
        }
      ]
    end
  end
end
