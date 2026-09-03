# frozen_string_literal: true

class ClientDecision < ApplicationRecord
  include OrganizationScoped
  include TypedId

  DECISIONS = %w[accepted rejected].freeze

  uses_typed_id "client_decision"

  belongs_to :application
  belongs_to :decided_by, class_name: "User"

  validates :decision, inclusion: { in: DECISIONS }
  validates :application_id, uniqueness: true
  validates :decided_at, presence: true
  validate :application_belongs_to_current_organization

  def target_stage
    decision == "accepted" ? "selected" : "rejected"
  end

  private

  def application_belongs_to_current_organization
    return unless application && application.organization_id != organization_id

    errors.add(:application, "must belong to the current organization")
  end
end
