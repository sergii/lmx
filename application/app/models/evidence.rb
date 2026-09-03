# frozen_string_literal: true

class Evidence < ApplicationRecord
  include OrganizationScoped
  include TypedId

  SOURCE_TYPES = %w[transcript interviewer_note resume live_coding take_home_assignment].freeze

  uses_typed_id "evidence"

  belongs_to :interview
  has_many :competency_assessment_evidences, dependent: :restrict_with_error
  has_many :competency_assessments, through: :competency_assessment_evidences

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :claim, presence: true
  validates :confidence, numericality: { in: 0..1 }, allow_nil: true
  validate :interview_belongs_to_current_organization

  private

  def interview_belongs_to_current_organization
    errors.add(:interview, "must belong to the current organization") if interview && interview.organization_id != organization_id
  end
end
