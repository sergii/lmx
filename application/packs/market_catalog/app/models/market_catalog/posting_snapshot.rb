# frozen_string_literal: true

module MarketCatalog
  class PostingSnapshot < ApplicationRecord
    self.table_name = "market_catalog_posting_snapshots"

    include TypedId

    PRESENCE_STATES = %w[
      present
      missing
      explicit_closed
      unknown
    ].freeze

    uses_typed_id "posting_snapshot"

    belongs_to :job_posting,
      class_name: "MarketCatalog::JobPosting",
      inverse_of: :snapshots

    normalizes :presence_state, :description_fingerprint, :content_digest,
      :normalizer_key, :normalizer_version,
      with: -> { _1.strip.downcase }
    normalizes :title, with: -> { _1.strip.gsub(/\s+/, " ").presence }

    validates :source_observation_id, presence: true, uniqueness: true
    validates :observed_at, presence: true
    validates :presence_state, inclusion: { in: PRESENCE_STATES }
    validates :content_digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :normalizer_key, :normalizer_version, presence: true
    validate :facts_are_object
    validate :metadata_are_object

    def readonly?
      persisted?
    end

    private

    def facts_are_object
      errors.add(:facts, "must be an object") unless facts.is_a?(Hash)
    end

    def metadata_are_object
      errors.add(:metadata, "must be an object") unless metadata.is_a?(Hash)
    end
  end
end
