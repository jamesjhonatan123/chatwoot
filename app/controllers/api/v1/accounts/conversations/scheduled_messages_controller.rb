class Api::V1::Accounts::Conversations::ScheduledMessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :scheduled_message, only: [:destroy]

  def index
    @scheduled_messages = @conversation.scheduled_messages.pending.order(:scheduled_at)
  end

  def create
    @scheduled_message = @conversation.scheduled_messages.create!(
      account: Current.account,
      user: Current.user,
      content: scheduled_message_params[:content],
      private: scheduled_message_params[:private] || false,
      scheduled_at: Time.zone.parse(scheduled_message_params[:scheduled_at].to_s),
      template_params: scheduled_message_params[:template_params] || {},
      media_asset_ids: Array(scheduled_message_params[:media_asset_ids]).compact
    )
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.message)
  end

  def destroy
    @scheduled_message.cancel!
    head :ok
  end

  private

  def scheduled_message
    @scheduled_message ||= @conversation.scheduled_messages.find(params[:id])
  end

  def scheduled_message_params
    params.require(:scheduled_message).permit(
      :content,
      :private,
      :scheduled_at,
      media_asset_ids: [],
      template_params: {}
    ).tap do |whitelisted|
      # Allow nested processed_params for WhatsApp templates
      if params[:scheduled_message][:template_params].present?
        whitelisted[:template_params] = params[:scheduled_message][:template_params].permit!.to_h
      end
    end
  end
end
