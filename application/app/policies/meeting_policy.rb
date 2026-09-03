# frozen_string_literal: true

class MeetingPolicy < ApplicationPolicy
  def index?
    internal_membership?
  end

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
