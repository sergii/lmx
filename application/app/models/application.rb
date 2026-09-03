# frozen_string_literal: true

class Application < ApplicationRecord
  include TypedId
  include OrganizationScoped

  uses_typed_id "application"


  STAGES = %w[
    sourced recruiter_screen english_check technical_interview internal_approval
    presented client_interviews selected rejected
  ].freeze
  CLIENT_VISIBLE_STAGES = %w[presented client_interviews selected].freeze

  belongs_to :candidate
  belongs_to :job
  belongs_to :sourced_by, class_name: "User", optional: true
  has_one :client_decision, dependent: :restrict_with_error
  has_many :meetings, dependent: :restrict_with_error
  has_many :interviews, dependent: :restrict_with_error
  has_many :stage_events, class_name: "ApplicationStageEvent", dependent: :restrict_with_error
  validates :stage, inclusion: { in: STAGES }
  validates :candidate_id, uniqueness: { scope: :job_id }
  validates :client_portal_id, presence: true, uniqueness: true
  validate :records_belong_to_current_organization
  before_validation :assign_client_portal_id, on: :create

  scope :client_visible_to_client, -> { where(client_visible: true, stage: CLIENT_VISIBLE_STAGES) }

  def client_company
    job.project.client_company
  end

  def move_to!(stage:, moved_by:)
    raise ArgumentError, "Unknown stage" unless STAGES.include?(stage)
    return if self.stage == stage

    transaction do
      previous_stage = self.stage
      update!(stage:, client_visible: true) if stage == "presented"
      update!(stage:) unless stage == "presented"
      stage_events.create!(from_stage: previous_stage, to_stage: stage, moved_by:, occurred_at: Time.current)
    end
  end

  def client_decision_recipient
    return sourced_by if sourced_by && sourced_by.memberships.active.where(organization:).where.not(role: %w[client_hiring_manager client_interviewer]).exists?

    organization.memberships.active.where(role: %w[workspace_admin recruiting_ops_lead recruiter]).order(:created_at).first&.user
  end

  private

  def assign_client_portal_id
    self.client_portal_id ||= "application_#{SecureRandom.urlsafe_base64(18)}"
  end

  def records_belong_to_current_organization
    errors.add(:candidate, "must belong to the current organization") if candidate && candidate.organization_id != organization_id
    errors.add(:job, "must belong to the current organization") if job && job.organization_id != organization_id
  end
end
