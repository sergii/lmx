# frozen_string_literal: true

require "digest"

module MarketCatalog
  class JobPosting < ApplicationRecord
    self.table_name = "market_catalog_job_postings"

    include TypedId

    LIFECYCLE_STATES = %w[
      present
      missing
      probably_closed
      closed
      reappeared
    ].freeze

    uses_typed_id "posting"

    belongs_to :job_opening,
      class_name: "MarketCatalog::JobOpening",
      inverse_of: :job_postings,
      optional: true
    belongs_to :publisher_company,
      class_name: "MarketCatalog::Company",
      inverse_of: :published_job_postings,
      optional: true
    has_many :resolution_decisions,
      class_name: "MarketCatalog::ResolutionDecision",
      inverse_of: :job_posting,
      dependent: :restrict_with_exception
    has_many :snapshots,
      class_name: "MarketCatalog::PostingSnapshot",
      inverse_of: :job_posting,
      dependent: :restrict_with_exception

    normalizes :source_key, with: -> { _1.strip.downcase }
    normalizes :external_id, with: -> { _1.strip.presence }
    normalizes :canonical_url, :application_url, with: -> { _1.strip.presence }
    normalizes :title, with: -> { _1.strip.gsub(/\s+/, " ") }
    normalizes :description_fingerprint, with: -> { _1.strip.downcase.presence }

    before_validation :derive_normalized_title
    before_validation :derive_url_digests

    validates :source_key, presence: true, format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
    validates :title, :normalized_title, presence: true
    validates :lifecycle_state, inclusion: { in: LIFECYCLE_STATES }
    validates :first_seen_at, :last_confirmed_present_at, presence: true
    validates :canonical_url, :application_url,
      format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) },
      allow_blank: true
    validates :canonical_url_digest, :application_url_digest,
      format: { with: /\A[0-9a-f]{64}\z/ },
      allow_blank: true
    validate :has_stable_identity_signal
    validate :last_present_not_before_first_seen

    class << self
      def url_digest(value)
        normalized = value.to_s.strip.presence
        Digest::SHA256.hexdigest(normalized) if normalized
      end
    end

    private

    def derive_normalized_title
      self.normalized_title = title.to_s.strip.downcase.gsub(/\s+/, " ")
    end

    def derive_url_digests
      self.canonical_url_digest = self.class.url_digest(canonical_url)
      self.application_url_digest = self.class.url_digest(application_url)
    end

    def has_stable_identity_signal
      return if external_id.present? || canonical_url.present? || application_url.present?

      errors.add(:base, "posting requires external_id, canonical_url, or application_url")
    end

    def last_present_not_before_first_seen
      return if first_seen_at.blank? || last_confirmed_present_at.blank? || last_confirmed_present_at >= first_seen_at

      errors.add(:last_confirmed_present_at, "must not be before first_seen_at")
    end
  end
end
