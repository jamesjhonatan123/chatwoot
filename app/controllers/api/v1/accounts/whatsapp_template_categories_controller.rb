class Api::V1::Accounts::WhatsappTemplateCategoriesController < Api::V1::Accounts::BaseController
  before_action :fetch_category, except: [:index, :create]
  before_action :check_authorization

  def index
    @categories = Current.account.whatsapp_template_categories
  end

  def create
    @category = Current.account.whatsapp_template_categories.create!(permitted_params)
    @category.assign_templates!(params[:template_names]) if params[:template_names].present?
    render :show
  end

  def update
    @category.update!(permitted_params)
    @category.assign_templates!(params[:template_names]) if params.key?(:template_names)
    render :show
  end

  def destroy
    @category.destroy!
    head :ok
  end

  # Move um template para esta categoria. Como um template so pertence a uma
  # categoria por vez, isto tambem o tira da anterior.
  def assign
    @category.assign_templates!(params[:template_names])
    render :show
  end

  def unassign
    @category.unassign_templates!(params[:template_names])
    render :show
  end

  private

  def fetch_category
    @category = Current.account.whatsapp_template_categories.find(params[:id])
  end

  def check_authorization
    authorize(WhatsappTemplateCategory)
  end

  def permitted_params
    params.require(:whatsapp_template_category).permit(:name, :color)
  end
end
