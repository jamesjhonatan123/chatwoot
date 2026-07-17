# == Schema Information
#
# Table name: follow_up_steps
#
#  id               :bigint           not null, primary key
#  due_at           :datetime         not null
#  error_message    :text
#  position         :integer          default(0), not null
#  result           :jsonb            not null
#  status           :integer          default("scheduled"), not null
#  step_config      :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  follow_up_run_id :bigint           not null
#
# Indexes
#
#  index_follow_up_steps_on_follow_up_run_id               (follow_up_run_id)
#  index_follow_up_steps_on_follow_up_run_id_and_position  (follow_up_run_id,position)
#  index_follow_up_steps_on_status_and_due_at              (status,due_at)
#
# Foreign Keys
#
#  fk_rails_...  (follow_up_run_id => follow_up_runs.id)
#
class FollowUpStep < ApplicationRecord
  belongs_to :follow_up_run

  enum status: { scheduled: 0, running: 1, skipped: 2, done: 3, cancelled: 4, failed: 5 }

  validates :due_at, presence: true
  validates :position, presence: true

  after_create_commit :enqueue_execute_job

  def cancel!
    return unless scheduled?

    update!(status: :cancelled)
  end

  private

  def enqueue_execute_job
    FollowUps::ExecuteStepJob.set(wait_until: due_at).perform_later(id)
  end
end
