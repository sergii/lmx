# frozen_string_literal: true

class SourcingBrief < ApplicationRecord
  include OrganizationScoped
  include TypedId

  STATUSES = %w[draft approved].freeze

  uses_typed_id "sourcing_brief"

  belongs_to :job
  belongs_to :approved_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validate :job_belongs_to_current_organization

  private

  def job_belongs_to_current_organization
    return unless job && job.organization_id != organization_id

    errors.add(:job, "must belong to the current organization")
  end
end
