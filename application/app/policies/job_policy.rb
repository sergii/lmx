# frozen_string_literal: true

class JobPolicy < ApplicationPolicy
  def index?
    internal_membership?
  end

  def create?
    internal_membership?
  end

  def show?
    internal_membership? && record.organization_id == membership.organization_id
  end

  def update?
    show?
  end

  private

  def internal_membership?
    user.present? && membership.present? && !membership.client_portal?
  end
end
