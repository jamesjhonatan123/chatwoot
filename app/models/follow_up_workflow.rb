# == Schema Information
#
# Table name: follow_up_workflows
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE), not null
#  description   :text
#  name          :string           not null
#  preset_key    :string
#  steps         :jsonb            not null
#  system_preset :boolean          default(FALSE), not null
#  trigger_mode  :string           default("manual"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#
# Indexes
#
#  index_follow_up_workflows_on_account_id                 (account_id)
#  index_follow_up_workflows_on_account_id_and_active      (account_id,active)
#  index_follow_up_workflows_on_account_id_and_preset_key  (account_id,preset_key) UNIQUE WHERE (preset_key IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class FollowUpWorkflow < ApplicationRecord
  TRIGGER_MODES = %w[manual automation both].freeze

  belongs_to :account
  has_many :follow_up_runs, dependent: :nullify

  validates :name, presence: true
  validates :trigger_mode, inclusion: { in: TRIGGER_MODES }
  validates :steps, presence: true
  validate :steps_must_be_array

  scope :active, -> { where(active: true) }
  scope :manual_eligible, -> { active.where(trigger_mode: %w[manual both]) }
  scope :automation_eligible, -> { active.where(trigger_mode: %w[automation both]) }

  def self.ensure_presets_for!(account)
    FollowUps::PresetSeeder.new(account: account).perform!
  end

  private

  def steps_must_be_array
    errors.add(:steps, 'must be an array') unless steps.is_a?(Array)
  end
end
