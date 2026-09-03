# frozen_string_literal: true

class JobPostingPolicy < ApplicationPolicy
  def create?
    internal_membership?
  end

  def update?
    internal_membership? && record.organization_id == membership.organization_id
  end

  private

  def internal_membership?
    user.present? && membership.present? && !membership.client_portal?
  end
end
