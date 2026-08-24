# == Schema Information
#
# Table name: media_assets
#
#  id           :bigint           not null, primary key
#  byte_size    :bigint           default(0), not null
#  content_type :string           default(""), not null
#  description  :text
#  file_name    :string           default(""), not null
#  file_type    :integer          default("image"), not null
#  title        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_media_assets_on_account_id                 (account_id)
#  index_media_assets_on_account_id_and_created_at  (account_id,created_at)
#  index_media_assets_on_account_id_and_file_type   (account_id,file_type)
#  index_media_assets_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#

class MediaAsset < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :account
  belongs_to :user

  has_one_attached :file

  enum file_type: { image: 0, audio: 1, video: 2, file: 3 }

  validates :file, presence: true, on: :create
  validates :file_name, presence: true
  validate :acceptable_file, if: -> { file.attached? }

  before_validation :sync_file_metadata, if: -> { file.attached? }

  scope :images, -> { where(file_type: :image) }
  scope :documents, -> { where(file_type: :file) }
  scope :search, lambda { |query|
    return all if query.blank?

    where('file_name ILIKE :q OR title ILIKE :q', q: "%#{query}%")
  }

  def file_url
    file.attached? ? url_for(file) : ''
  end

  def thumb_url
    return '' unless file.attached? && image?

    begin
      url_for(file.representation(resize_to_fill: [250, nil]))
    rescue ActiveStorage::UnrepresentableError
      ''
    end
  end

  def blob
    file.blob if file.attached?
  end

  def blob_signed_id
    blob&.signed_id
  end

  private

  def sync_file_metadata
    self.file_name = file.filename.to_s if file_name.blank?
    self.content_type = file.content_type.to_s
    self.byte_size = file.byte_size.to_i
    self.file_type = classify_file_type(file.content_type)
  end

  def classify_file_type(content_type)
    return :image if content_type.to_s.start_with?('image/')
    return :video if content_type.to_s.start_with?('video/')
    return :audio if content_type.to_s.start_with?('audio/')

    :file
  end

  def acceptable_file
    validate_file_size(file.byte_size)
    validate_file_content_type(file.content_type)
  end

  def validate_file_content_type(file_content_type)
    allowed = file_content_type.to_s.start_with?('image/', 'video/', 'audio/') ||
              Attachment::ACCEPTABLE_FILE_TYPES.include?(file_content_type)
    errors.add(:file, 'type not supported') unless allowed
  end

  def validate_file_size(size)
    limit_mb = GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', 40).to_i
    limit_mb = 40 if limit_mb <= 0
    errors.add(:file, 'size is too big') if size > limit_mb.megabytes
  end
end
