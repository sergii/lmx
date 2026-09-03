# frozen_string_literal: true

class Job < ApplicationRecord
  include TypedId
  include OrganizationScoped

  uses_typed_id "job"


  STATUSES = %w[draft open closed].freeze

  belongs_to :project
  has_many :applications, class_name: "Application", dependent: :restrict_with_error
  has_many :job_postings, dependent: :restrict_with_error
  has_one :sourcing_brief, dependent: :restrict_with_error
  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :project_belongs_to_current_organization

  private

  def project_belongs_to_current_organization
    errors.add(:project, "must belong to the current organization") if project && project.organization_id != organization_id
  end
end
