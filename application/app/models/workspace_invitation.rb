# frozen_string_literal: true

class WorkspaceInvitation < ApplicationRecord
  include OrganizationScoped
  include TypedId

  ROLES = %w[workspace_admin recruiting_ops_lead recruiter].freeze
  STATUSES = %w[pending accepted revoked].freeze

  uses_typed_id "workspace_invitation"

  belongs_to :invited_by, class_name: "User"

  normalizes :email, with: -> { _1.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { scope: :organization_id }
  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
end
