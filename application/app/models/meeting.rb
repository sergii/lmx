# frozen_string_literal: true

class Meeting < ApplicationRecord
  include OrganizationScoped
  include TypedId

  KINDS = %w[
    sourcing_intro recruiter_screen technical_interview hiring_manager_interview
    client_interview follow_up offer_call check_in
  ].freeze
  STATUSES = %w[scheduled completed cancelled no_show].freeze

  uses_typed_id "meeting"

  belongs_to :candidate
  belongs_to :application, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :reminder_task, class_name: "Task", optional: true
  has_one :interview

  before_validation :assign_sequence, on: :create

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :scheduled_at, presence: true
  validates :sequence, numericality: { only_integer: true, greater_than: 0 }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :records_belong_to_current_organization
  validate :application_belongs_to_candidate

  def scheduled?
    status == "scheduled"
  end

  private

  def assign_sequence
    return if sequence.present? || candidate.blank? || kind.blank?

    scope = self.class.where(candidate:, kind:)
    scope = application ? scope.where(application:) : scope.where(application_id: nil)
    self.sequence = scope.maximum(:sequence).to_i + 1
  end

  def records_belong_to_current_organization
    errors.add(:candidate, "must belong to the current organization") if candidate && candidate.organization_id != organization_id
    errors.add(:application, "must belong to the current organization") if application && application.organization_id != organization_id
  end

  def application_belongs_to_candidate
    return unless application && candidate && application.candidate_id != candidate_id

    errors.add(:application, "must belong to the selected candidate")
  end
end
