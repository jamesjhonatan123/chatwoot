# == Schema Information
#
# Table name: follow_up_runs
#
#  id                    :bigint           not null, primary key
#  anchor_at             :datetime         not null
#  cancel_on_incoming    :boolean          default(TRUE), not null
#  context               :jsonb            not null
#  current_step_index    :integer          default(0), not null
#  next_due_at           :datetime
#  run_type              :string           default("workflow"), not null
#  status                :integer          default("active"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  conversation_id       :bigint           not null
#  follow_up_workflow_id :bigint
#  user_id               :bigint           not null
#
# Indexes
#
#  index_follow_up_runs_on_account_id                             (account_id)
#  index_follow_up_runs_on_account_id_and_status_and_next_due_at  (account_id,status,next_due_at)
#  index_follow_up_runs_on_conversation_id                        (conversation_id)
#  index_follow_up_runs_on_conversation_id_and_status             (conversation_id,status)
#  index_follow_up_runs_on_follow_up_workflow_id                  (follow_up_workflow_id)
#  index_follow_up_runs_on_status_and_next_due_at                 (status,next_due_at)
#  index_follow_up_runs_on_user_id                                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (follow_up_workflow_id => follow_up_workflows.id)
#  fk_rails_...  (user_id => users.id)
#
class FollowUpRun < ApplicationRecord
  RUN_TYPES = %w[remind_me message_if_no_reply workflow].freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :user
  belongs_to :follow_up_workflow, optional: true
  has_many :follow_up_steps, dependent: :destroy

  enum status: { active: 0, completed: 1, cancelled: 2, failed: 3 }

  validates :run_type, inclusion: { in: RUN_TYPES }
  validates :anchor_at, presence: true

  scope :due, -> { active.where('next_due_at <= ?', Time.current) }
  scope :upcoming, -> { active.where.not(next_due_at: nil).order(:next_due_at) }

  after_commit :sync_conversation_due_at

  def cancel!(reason: 'cancelled')
    return unless active?

    transaction do
      follow_up_steps.scheduled.find_each(&:cancel!)
      update!(status: :cancelled, next_due_at: nil, context: context.merge('cancel_reason' => reason))
    end
  end

  def mark_completed!
    update!(status: :completed, next_due_at: nil)
  end

  def mark_failed!(message)
    update!(status: :failed, next_due_at: nil, context: context.merge('error' => message))
  end

  def workflow_steps
    if follow_up_workflow.present?
      follow_up_workflow.steps
    else
      context['steps'] || []
    end
  end

  private

  def sync_conversation_due_at
    FollowUps::SyncConversationDueAtService.new(conversation: conversation).perform
  end
end
