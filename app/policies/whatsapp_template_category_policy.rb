class WhatsappTemplateCategoryPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def assign?
    @account_user.administrator?
  end

  def unassign?
    @account_user.administrator?
  end
end
