# frozen_string_literal: true

module MarketCatalog
  class JobOpening < ApplicationRecord
    self.table_name = "market_catalog_job_openings"

    include TypedId

    LIFECYCLE_STATES = %w[
      open
      missing
      probably_closed
      closed
      reopened
    ].freeze

    uses_typed_id "opening"

    belongs_to :primary_company,
      class_name: "MarketCatalog::Company",
      inverse_of: :job_openings,
      optional: true
    has_many :job_postings,
      class_name: "MarketCatalog::JobPosting",
      inverse_of: :job_opening,
      dependent: :restrict_with_exception
    has_many :opening_parties,
      class_name: "MarketCatalog::OpeningParty",
      inverse_of: :job_opening,
      dependent: :restrict_with_exception

    normalizes :canonical_title, with: -> { _1.strip.gsub(/\s+/, " ") }

    before_validation :derive_normalized_title

    validates :canonical_title, presence: true
    validates :normalized_title, presence: true
    validates :lifecycle_state, inclusion: { in: LIFECYCLE_STATES }
    validates :first_seen_at, :last_seen_at, presence: true
    validate :last_seen_not_before_first_seen

    private

    def derive_normalized_title
      self.normalized_title = canonical_title.to_s.strip.downcase.gsub(/\s+/, " ")
    end

    def last_seen_not_before_first_seen
      return if first_seen_at.blank? || last_seen_at.blank? || last_seen_at >= first_seen_at

      errors.add(:last_seen_at, "must not be before first_seen_at")
    end
  end
end
