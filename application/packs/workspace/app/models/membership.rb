# frozen_string_literal: true

class Membership < ApplicationRecord
  include TypedId

  uses_typed_id "membership"

  ROLES = %w[workspace_admin recruiting_ops_lead recruiter client_hiring_manager client_interviewer].freeze

  belongs_to :user
  belongs_to :organization
  belongs_to :client_company, optional: true

  scope :active, -> { where(active: true) }

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :organization_id }
  validate :client_membership_matches_organization

  def client_portal?
    role.in?(%w[client_hiring_manager client_interviewer]) && client_company_id.present?
  end

  def workspace_admin?
    role == "workspace_admin"
  end

  private

  def client_membership_matches_organization
    errors.add(:client_company, "is required for client roles") if role.in?(%w[client_hiring_manager client_interviewer]) && client_company_id.blank?
    return unless client_company

    errors.add(:client_company, "must belong to the membership organization") if client_company.organization_id != organization_id
  end
end
