# frozen_string_literal: true

class SourceRun < ApplicationRecord
  include TypedId

  STATUSES = %w[running succeeded failed].freeze
  TERMINAL_STATUSES = %w[succeeded failed].freeze

  uses_typed_id "source_run"

  has_many :raw_payloads, dependent: :restrict_with_exception
  has_many :ingestion_records, dependent: :restrict_with_exception
  has_many :source_observations, dependent: :restrict_with_exception

  normalizes :source_key, with: -> { _1.strip.downcase }
  normalizes :transport, with: -> { _1.strip.downcase }
  normalizes :status, with: -> { _1.strip.downcase }
  normalizes :run_key, :collector_version, :adapter_version, :parser_version, :error_class,
    with: -> { _1.strip.presence }
  normalizes :idempotency_key, with: -> { _1.strip.downcase }

  validates :source_key, presence: true, format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
  validates :transport, inclusion: { in: Acquisition::PERSISTED_TRANSPORTS }
  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true
  validates :idempotency_key, presence: true, uniqueness: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :fetched_count, :discovered_count, :observed_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :finished_at_matches_status
  validate :finished_at_is_not_before_started_at
  validate :result_information_matches_status
  validate :terminal_runs_are_immutable, on: :update

  def terminal?
    status.in?(TERMINAL_STATUSES)
  end

  def successful?
    status == "succeeded"
  end

  private

  def finished_at_matches_status
    if terminal? && finished_at.blank?
      errors.add(:finished_at, "must be present for a terminal source run")
    elsif status == "running" && finished_at.present?
      errors.add(:finished_at, "must be blank while a source run is running")
    end
  end

  def finished_at_is_not_before_started_at
    return if started_at.blank? || finished_at.blank? || finished_at >= started_at

    errors.add(:finished_at, "cannot be before started_at")
  end

  def result_information_matches_status
    if status == "succeeded"
      errors.add(:observed_count, "must be present for a successful source run") if observed_count.nil?
      errors.add(:base, "successful source runs cannot contain failure information") if failure_information?
    elsif status == "failed"
      errors.add(:base, "failed source runs must preserve failure information") unless failure_information?
    elsif failure_information?
      errors.add(:base, "running source runs cannot contain failure information")
    end
  end

  def failure_information?
    error_class.present? || error_message.present? || error_details.present?
  end

  def terminal_runs_are_immutable
    return unless attribute_in_database("status").in?(TERMINAL_STATUSES)

    errors.add(:base, "terminal source runs are immutable")
  end
end
