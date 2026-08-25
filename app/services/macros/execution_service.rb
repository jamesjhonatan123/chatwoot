class Macros::ExecutionService < ActionService
  def initialize(macro, conversation, user)
    super(conversation)
    @macro = macro
    @account = macro.account
    @user = user
    Current.user = user
  end

  def perform
    @macro.actions.each do |action|
      action = action.with_indifferent_access
      begin
        send(action[:action_name], action[:action_params])
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  ensure
    Current.reset
  end

  private

  def assign_agent(agent_ids)
    agent_ids = agent_ids.map { |id| id == 'self' ? @user.id : id }
    super(agent_ids)
  end

  def add_private_note(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: true }

    # Added reload here to ensure conversation us persistent with the latest updates
    mb = Messages::MessageBuilder.new(@user, @conversation.reload, params)
    mb.perform
  end

  def send_message(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: false }

    # Added reload here to ensure conversation us persistent with the latest updates
    mb = Messages::MessageBuilder.new(@user, @conversation.reload, params)
    mb.perform
  end

  def send_attachment(params)
    return if conversation_a_tweet?

    caption, media_asset_id, blob_ids = normalize_attachment_params(params)
    blobs = resolve_attachment_blobs(media_asset_id, blob_ids)
    return if blobs.blank?

    builder_params = { content: caption.presence, private: false, attachments: blobs }
    Messages::MessageBuilder.new(@user, @conversation.reload, builder_params).perform
  end

  def normalize_attachment_params(params)
    payload = params.is_a?(Array) ? params[0] : params

    if payload.is_a?(Hash)
      payload = payload.with_indifferent_access
      return [
        payload[:caption].to_s,
        payload[:media_asset_id],
        Array(payload[:blob_ids] || payload[:blob_id]).compact
      ]
    end

    # Legacy: action_params is an array of numeric blob ids
    ['', nil, Array(params).compact]
  end

  def resolve_attachment_blobs(media_asset_id, blob_ids)
    if media_asset_id.present?
      return MediaAssets::ResolveBlobsService.new(
        account: @account,
        media_asset_ids: [media_asset_id]
      ).perform
    end

    return [] if blob_ids.blank?
    return [] unless @macro.files.attached?

    ActiveStorage::Blob.where(id: blob_ids)
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: 'macro.executed')
    WebhookJob.perform_later(webhook_url.first, payload)
  end
end

Macros::ExecutionService.include_mod_with('Macros::ExecutionService')
