module AttachmentConcern
  extend ActiveSupport::Concern

  def validate_and_prepare_attachments(actions, record = nil)
    blobs = []
    return [blobs, actions, nil] if actions.blank?

    sanitized = actions.map do |action|
      action = action.to_unsafe_h.with_indifferent_access if action.respond_to?(:to_unsafe_h)
      action = action.with_indifferent_access if action.is_a?(Hash)
      next action unless action[:action_name] == 'send_attachment'

      result = process_attachment_action(action, record, blobs)
      return [nil, nil, I18n.t('errors.attachments.invalid')] unless result

      result
    end

    [blobs, sanitized, nil]
  end

  private

  def process_attachment_action(action, record, blobs)
    first_param = action[:action_params].is_a?(Array) ? action[:action_params].first : action[:action_params]
    first_param = first_param.to_unsafe_h if first_param.respond_to?(:to_unsafe_h)

    if first_param.is_a?(Hash)
      payload = first_param.with_indifferent_access
      return process_media_asset_action(action, payload) if payload[:media_asset_id].present?
    end

    blob_id = first_param
    blob = ActiveStorage::Blob.find_signed(blob_id.to_s)

    return action.merge(action_params: [blob.id]).tap { blobs << blob } if blob.present?
    return action if blob_already_attached?(record, blob_id)

    nil
  end

  def process_media_asset_action(action, payload)
    asset = Current.account.media_assets.find_by(id: payload[:media_asset_id])
    return nil if asset.blank?

    action.merge(
      action_params: [{
        'media_asset_id' => asset.id,
        'caption' => payload[:caption].to_s
      }]
    )
  end

  def blob_already_attached?(record, blob_id)
    record&.files&.any? { |f| f.blob_id == blob_id.to_i }
  end
end
