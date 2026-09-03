# frozen_string_literal: true

class CompetencyAssessment < ApplicationRecord
  include OrganizationScoped
  include TypedId

  STATUSES = %w[not_assessed insufficient_evidence weak demonstrated].freeze

  uses_typed_id "competency_assessment"

  belongs_to :interview_assessment
  belongs_to :competency
  has_many :competency_assessment_evidences, dependent: :restrict_with_error
  has_many :evidences, through: :competency_assessment_evidences

  validates :status, inclusion: { in: STATUSES }
  validates :confidence, numericality: { in: 0..1 }, allow_nil: true
  validate :records_belong_to_current_organization

  private

  def records_belong_to_current_organization
    errors.add(:interview_assessment, "must belong to the current organization") if interview_assessment && interview_assessment.organization_id != organization_id
    errors.add(:competency, "must belong to the current organization") if competency && competency.organization_id != organization_id
  end
end
