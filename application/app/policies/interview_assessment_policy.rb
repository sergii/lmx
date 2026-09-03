# frozen_string_literal: true

class InterviewAssessmentPolicy < ApplicationPolicy
  def show?
    internal_membership? && record.organization_id == membership.organization_id
  end

  def create?
    internal_membership? && record.interview.assessable?
  end

  def update?
    show? && record.status != "approved"
  end

  relation_scope do |relation|
    next relation.none unless internal_membership?

    relation.where(organization_id: membership.organization_id)
  end

  private

  def internal_membership?
    user.present? && membership.present? && !membership.client_portal?
  end
end
