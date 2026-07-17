FactoryBot.define do
  factory :follow_up_run do
    account
    conversation
    user
    run_type { 'workflow' }
    status { :active }
    anchor_at { Time.current }
    cancel_on_incoming { true }
    current_step_index { 0 }
    next_due_at { 1.hour.from_now }
    context { {} }

    trait :failed do
      status { :failed }
      next_due_at { nil }
      context { { 'error' => 'Something went wrong' } }
    end

    trait :completed do
      status { :completed }
      next_due_at { nil }
    end

    trait :cancelled do
      status { :cancelled }
      next_due_at { nil }
      context { { 'cancel_reason' => 'cancelled_by_user' } }
    end
  end
end
