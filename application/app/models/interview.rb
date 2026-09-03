# frozen_string_literal: true

class Interview < ApplicationRecord
  include OrganizationScoped
  include TypedId

  STATUSES = %w[draft completed cancelled].freeze

  uses_typed_id "interview"

  belongs_to :candidate
  belongs_to :application, optional: true
  belongs_to :meeting, optional: true
  belongs_to :created_by, class_name: "User"
  has_many :assessments, class_name: "InterviewAssessment", dependent: :restrict_with_error
  has_many :evidences, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }
  validate :records_belong_to_current_organization
  validate :application_belongs_to_candidate
  validate :meeting_is_valid_for_interview

  def assessable?
    completed? && !meeting&.cancelled?
  end

  def completed?
    status == "completed"
  end

  private

  def records_belong_to_current_organization
    errors.add(:candidate, "must belong to the current organization") if candidate && candidate.organization_id != organization_id
    errors.add(:application, "must belong to the current organization") if application && application.organization_id != organization_id
    errors.add(:meeting, "must belong to the current organization") if meeting && meeting.organization_id != organization_id
  end

  def application_belongs_to_candidate
    return unless application && candidate && application.candidate_id != candidate_id

    errors.add(:application, "must belong to the selected candidate")
  end

  def meeting_is_valid_for_interview
    return unless meeting

    errors.add(:meeting, "must belong to the selected candidate") if candidate && meeting.candidate_id != candidate_id
    errors.add(:meeting, "cannot be cancelled") if meeting.status == "cancelled"
  end
end
