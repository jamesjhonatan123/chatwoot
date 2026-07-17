class Api::V1::Accounts::FollowUpWorkflowsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :ensure_presets
  before_action :follow_up_workflow, only: [:show, :update, :destroy]

  def index
    @follow_up_workflows = Current.account.follow_up_workflows.order(:name)
  end

  def show; end

  def create
    @follow_up_workflow = Current.account.follow_up_workflows.create!(workflow_params)
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.message)
  end

  def update
    @follow_up_workflow.update!(workflow_params)
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.message)
  end

  def destroy
    return render_could_not_create_error('System presets cannot be deleted') if @follow_up_workflow.system_preset?

    @follow_up_workflow.destroy!
    head :ok
  end

  def analytics
    @analytics = FollowUps::AnalyticsService.new(account: Current.account).perform
  end

  private

  def ensure_presets
    FollowUpWorkflow.ensure_presets_for!(Current.account)
  end

  def follow_up_workflow
    @follow_up_workflow ||= Current.account.follow_up_workflows.find(params[:id])
  end

  def workflow_params
    params.require(:follow_up_workflow).permit(
      :name,
      :description,
      :trigger_mode,
      :active,
      steps: [
        :type,
        :on_fail,
        { wait: [:value, :unit, :business_hours],
          conditions: [:attribute_key, :filter_operator, { values: [] }],
          actions: [:action_name, { action_params: [] }],
          branch: [:then_goto, :else_goto, { if: [:attribute_key, :filter_operator, { values: [] }] }] }
      ]
    ).tap do |whitelisted|
      if params[:follow_up_workflow][:steps].present?
        whitelisted[:steps] = params[:follow_up_workflow][:steps].map(&:permit!).map(&:to_h)
      end
    end
  end
end
