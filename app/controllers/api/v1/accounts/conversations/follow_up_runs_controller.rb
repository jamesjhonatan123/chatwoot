class Api::V1::Accounts::Conversations::FollowUpRunsController < Api::V1::Accounts::Conversations::BaseController
  before_action :follow_up_run, only: [:destroy, :retry]

  def index
    @follow_up_runs = @conversation.follow_up_runs.includes(:follow_up_workflow, :follow_up_steps, :user).order(created_at: :desc)
  end

  def create
    @follow_up_run = FollowUps::StartService.new(
      conversation: @conversation,
      user: Current.user,
      workflow: workflow,
      run_type: permitted_params[:run_type],
      due_at: permitted_params[:due_at],
      content: permitted_params[:content],
      template_params: permitted_params[:template_params],
      note: permitted_params[:note],
      cancel_on_incoming: permitted_params[:cancel_on_incoming],
      context: permitted_params[:context] || {}
    ).perform
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.message)
  end

  def destroy
    @follow_up_run.cancel!(reason: 'cancelled_by_user')
    head :ok
  end

  def retry
    @follow_up_run = FollowUps::RetryService.new(run: @follow_up_run).perform
  rescue ArgumentError => e
    render_could_not_create_error(e.message)
  end

  private

  def follow_up_run
    @follow_up_run ||= @conversation.follow_up_runs.find(params[:id])
  end

  def workflow
    return if permitted_params[:follow_up_workflow_id].blank?

    Current.account.follow_up_workflows.active.find(permitted_params[:follow_up_workflow_id])
  end

  def permitted_params
    params.require(:follow_up_run).permit(
      :run_type,
      :due_at,
      :content,
      :note,
      :cancel_on_incoming,
      :follow_up_workflow_id,
      template_params: {},
      context: {}
    ).tap do |whitelisted|
      if params[:follow_up_run][:template_params].present?
        whitelisted[:template_params] = params[:follow_up_run][:template_params].permit!.to_h
      end
      if params[:follow_up_run][:context].present?
        whitelisted[:context] = params[:follow_up_run][:context].permit!.to_h
      end
    end
  end
end
