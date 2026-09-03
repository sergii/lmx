# frozen_string_literal: true

class JobPosting < ApplicationRecord
  include OrganizationScoped
  include TypedId

  CHANNELS = %w[careers_site linkedin indeed other].freeze
  STATUSES = %w[draft published paused closed].freeze

  uses_typed_id "job_posting"

  belongs_to :job

  before_validation :set_status_timestamps

  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  validates :public_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validate :job_belongs_to_current_organization

  private

  def job_belongs_to_current_organization
    return unless job && job.organization_id != organization_id

    errors.add(:job, "must belong to the current organization")
  end

  def set_status_timestamps
    self.published_at ||= Time.current if status == "published"
    self.closed_at ||= Time.current if status == "closed"
  end
end
