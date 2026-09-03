# frozen_string_literal: true

class CompetencyAssessmentEvidence < ApplicationRecord
  include OrganizationScoped

  belongs_to :competency_assessment
  belongs_to :evidence

  validates :evidence_id, uniqueness: { scope: :competency_assessment_id }
  validate :records_belong_to_current_organization

  private

  def records_belong_to_current_organization
    errors.add(:competency_assessment, "must belong to the current organization") if competency_assessment && competency_assessment.organization_id != organization_id
    errors.add(:evidence, "must belong to the current organization") if evidence && evidence.organization_id != organization_id
  end
end
