# == Schema Information
#
# Table name: scheduled_messages
#
#  id              :bigint           not null, primary key
#  content         :text
#  media_asset_ids :jsonb            not null
#  private         :boolean          default(FALSE), not null
#  scheduled_at    :datetime         not null
#  status          :integer          default("pending"), not null
#  template_params :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  message_id      :bigint
#  user_id         :bigint           not null
#
# Indexes
#
#  index_scheduled_messages_on_account_id                  (account_id)
#  index_scheduled_messages_on_conversation_id             (conversation_id)
#  index_scheduled_messages_on_conversation_id_and_status  (conversation_id,status)
#  index_scheduled_messages_on_status_and_scheduled_at     (status,scheduled_at)
#  index_scheduled_messages_on_user_id                     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (user_id => users.id)
#

class ScheduledMessage < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :user
  belongs_to :message, optional: true

  enum status: { pending: 0, sent: 1, cancelled: 2, failed: 3 }

  validates :content, length: { maximum: 150_000 }, allow_blank: true
  validates :scheduled_at, presence: true
  validate :scheduled_at_must_be_future, on: :create
  validate :content_or_media_present

  scope :pending_for_conversation, ->(conversation_id) { pending.where(conversation_id: conversation_id).order(:scheduled_at) }

  after_create_commit :enqueue_send_job

  def cancel!
    return unless pending?

    update!(status: :cancelled)
  end

  def deliver!
    return unless pending?

    blobs = MediaAssets::ResolveBlobsService.new(
      account: account,
      media_asset_ids: media_asset_ids
    ).perform

    builder_params = {
      content: content,
      private: self[:private],
      message_type: 'outgoing'
    }
    builder_params[:template_params] = template_params if template_params.present?
    builder_params[:attachments] = blobs if blobs.present?

    message = Messages::MessageBuilder.new(user, conversation, builder_params).perform

    update!(status: :sent, message_id: message.id)
  rescue StandardError => e
    update!(status: :failed)
    Rails.logger.error("[ScheduledMessage] Failed to deliver ##{id}: #{e.message}")
    raise
  end

  def template?
    template_params.present?
  end

  private

  def content_or_media_present
    return if content.present? || media_asset_ids.present? || template_params.present?

    errors.add(:base, 'content or media is required')
  end

  def scheduled_at_must_be_future
    return if scheduled_at.blank?
    return if scheduled_at > Time.current

    errors.add(:scheduled_at, 'must be in the future')
  end

  def enqueue_send_job
    SendScheduledMessageJob.set(wait_until: scheduled_at).perform_later(id)
  end
end
