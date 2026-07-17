class Api::V1::Accounts::FollowUpRunsController < Api::V1::Accounts::BaseController
  before_action :follow_up_run, only: [:show, :retry]

  def index
    scope = Current.account.follow_up_runs.includes(:conversation, :follow_up_workflow, :user, :follow_up_steps)

    if history_mode?
      scope = apply_history_filters(scope)
      @follow_up_runs = scope.order(updated_at: :desc).limit(limit_param)
    else
      scope = scope.active if ActiveModel::Type::Boolean.new.cast(params[:active])
      scope = scope.where('next_due_at <= ?', Time.current.end_of_day) if params[:due] == 'today'
      scope = scope.where('next_due_at < ?', Time.current) if params[:due] == 'overdue'
      scope = scope.where(user_id: Current.user.id) if ActiveModel::Type::Boolean.new.cast(params[:mine])
      @follow_up_runs = scope.order(next_due_at: :asc).limit(limit_param)
    end
  end

  def show; end

  def retry
    @follow_up_run = FollowUps::RetryService.new(run: @follow_up_run).perform
  rescue ArgumentError => e
    render_could_not_create_error(e.message)
  end

  private

  def follow_up_run
    @follow_up_run ||= Current.account.follow_up_runs.includes(
      :conversation, :follow_up_workflow, :user, :follow_up_steps
    ).find(params[:id])
  end

  def history_mode?
    ActiveModel::Type::Boolean.new.cast(params[:history]) || params[:status].present?
  end

  def apply_history_filters(scope)
    if params[:status].present?
      statuses = params[:status].to_s.split(',').map(&:strip).select { |status| FollowUpRun.statuses.key?(status) }
      scope = scope.where(status: statuses) if statuses.present?
    end

    if params[:workflow_id].present?
      scope = scope.where(follow_up_workflow_id: params[:workflow_id])
    end

    if params[:conversation_id].present?
      conversation = Current.account.conversations.find_by(display_id: params[:conversation_id])
      scope = conversation ? scope.where(conversation_id: conversation.id) : scope.none
    end

    if params[:run_type].present?
      scope = scope.where(run_type: params[:run_type])
    end

    scope
  end

  def limit_param
    params.fetch(:limit, 50).to_i.clamp(1, 100)
  end
end
