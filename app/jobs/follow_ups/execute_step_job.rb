class FollowUps::ExecuteStepJob < ApplicationJob
  queue_as :default

  def perform(follow_up_step_id)
    step = FollowUpStep.find_by(id: follow_up_step_id)
    return if step.blank?

    FollowUps::ExecuteStepService.new(step: step).perform
  end
end
