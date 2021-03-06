# encoding: utf-8

class RolePolicy < ApplicationPolicy
  def index?
    @user.admin?
  end

  def new?
    @user.admin?
  end

  def unsubscribe_request?
    @user.admin?
  end

  def club_users?
    @user.admin? || @user.advisor? || @user.president?
  end

  def show?
    @user.admin? || @user.president?(@record.club_period.id)
  end

  def edit?
    @user.admin? || @user.president?(@record.club_period.id)
  end

  def update?
    @user.admin? || @user.president?(@record.club_period.id)
  end

  def create?
    true
  end

  def destroy?
    true
  end
end
