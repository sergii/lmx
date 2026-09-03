# frozen_string_literal: true

class InterviewAssessment < ApplicationRecord
  include OrganizationScoped
  include TypedId

  STATUSES = %w[draft submitted reviewed approved].freeze

  uses_typed_id "interview_assessment"

  belongs_to :interview
  belongs_to :assessor, class_name: "User"
  has_many :competency_assessments, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true
  validate :interview_belongs_to_current_organization
  validate :interview_is_assessable

  private

  def interview_belongs_to_current_organization
    errors.add(:interview, "must belong to the current organization") if interview && interview.organization_id != organization_id
  end

  def interview_is_assessable
    errors.add(:interview, "must be completed and not linked to a cancelled meeting") if interview && !interview.assessable?
  end
end
