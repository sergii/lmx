# frozen_string_literal: true

module MarketCatalog
  class ResolutionDecision < ApplicationRecord
    self.table_name = "market_catalog_resolution_decisions"

    include TypedId

    DECISION_TYPES = %w[
      link_posting
      unlink_posting
      relink_posting
    ].freeze

    uses_typed_id "resolution_decision"

    belongs_to :job_posting,
      class_name: "MarketCatalog::JobPosting",
      inverse_of: :resolution_decisions
    belongs_to :from_job_opening,
      class_name: "MarketCatalog::JobOpening",
      optional: true
    belongs_to :to_job_opening,
      class_name: "MarketCatalog::JobOpening",
      optional: true

    normalizes :decision_type, :resolver_key, :resolver_version, with: -> { _1.strip.downcase }

    validates :decision_type, inclusion: { in: DECISION_TYPES }
    validates :confidence,
      numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
    validates :resolver_key, :resolver_version, :decided_at, presence: true
    validate :evidence_is_array
    validate :opening_transition_matches_decision_type

    def readonly?
      persisted?
    end

    private

    def evidence_is_array
      errors.add(:evidence, "must be an array") unless evidence.is_a?(Array)
    end

    def opening_transition_matches_decision_type
      case decision_type
      when "link_posting"
        errors.add(:from_job_opening, "must be empty for a link") if from_job_opening_id.present?
        errors.add(:to_job_opening, "must be present for a link") if to_job_opening_id.blank?
      when "unlink_posting"
        errors.add(:from_job_opening, "must be present for an unlink") if from_job_opening_id.blank?
        errors.add(:to_job_opening, "must be empty for an unlink") if to_job_opening_id.present?
      when "relink_posting"
        errors.add(:from_job_opening, "must be present for a relink") if from_job_opening_id.blank?
        errors.add(:to_job_opening, "must be present for a relink") if to_job_opening_id.blank?
        errors.add(:to_job_opening, "must differ from from_job_opening") if from_job_opening_id == to_job_opening_id
      end
    end
  end
end
