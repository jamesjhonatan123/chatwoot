class FollowUps::ActionService < ActionService
  def initialize(conversation, run)
    super(conversation)
    @run = run
  end

  def send_message(params)
    payload = params.is_a?(Array) ? params[0] : params

    content = nil
    media_asset_id = nil
    template_params = @run.context['template_params']

    if payload.is_a?(Hash)
      payload = payload.with_indifferent_access
      content = payload[:message].presence || payload[:content]
      media_asset_id = payload[:media_asset_id]
      template_params = payload[:template_params].presence || template_params
    else
      content = payload
    end

    blobs = MediaAssets::ResolveBlobsService.new(
      account: @account,
      media_asset_ids: [media_asset_id]
    ).perform

    return if content.blank? && template_params.blank? && blobs.blank?

    builder_params = {
      content: content,
      private: false,
      message_type: 'outgoing'
    }
    builder_params[:template_params] = template_params if template_params.present?
    builder_params[:attachments] = blobs if blobs.present?

    Messages::MessageBuilder.new(@run.user, @conversation, builder_params).perform
  end

  def add_private_note(params)
    content = params.is_a?(Array) ? params[0] : params
    return if content.blank?

    Messages::MessageBuilder.new(@run.user, @conversation, {
                                   content: content,
                                   private: true,
                                   message_type: 'outgoing'
                                 }).perform
  end

  def notify_assignee(_params)
    assignee = @conversation.assignee || @run.user
    return if assignee.blank?

    NotificationBuilder.new(
      notification_type: :follow_up_due,
      user: assignee,
      account: @account,
      primary_actor: @conversation,
      secondary_actor: @run.user
    ).perform
  end

  def schedule_message(params)
    payload = params.is_a?(Array) ? params[0] : params
    return if payload.blank?

    payload = payload.with_indifferent_access
    @conversation.scheduled_messages.create!(
      account: @account,
      user: @run.user,
      content: payload[:content],
      private: payload[:private] || false,
      scheduled_at: Time.zone.parse(payload[:scheduled_at].to_s),
      template_params: payload[:template_params] || {}
    )
  end

  def start_follow_up(params)
    workflow_id = params.is_a?(Array) ? params[0] : params
    workflow = @account.follow_up_workflows.active.find_by(id: workflow_id)
    return if workflow.blank?

    FollowUps::StartService.new(
      conversation: @conversation,
      user: @run.user,
      workflow: workflow
    ).perform
  end

  def cancel_follow_ups(_params)
    @conversation.follow_up_runs.active.find_each { |run| run.cancel!(reason: 'cancelled_by_action') }
  end
end
