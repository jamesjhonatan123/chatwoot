class MediaAssetPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def create?
    @account_user.administrator? || @account_user.agent?
  end

  def update?
    @account_user.administrator? || @account_user.agent?
  end

  def destroy?
    return true if @account_user.administrator?
    return false unless @account_user.agent?
    return true if record.is_a?(Class)

    record.user_id == @user.id
  end
end
