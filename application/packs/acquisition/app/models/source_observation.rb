# frozen_string_literal: true

class SourceObservation < ApplicationRecord
  include TypedId

  uses_typed_id "source_observation"

  belongs_to :source_run
  belongs_to :ingestion_record
  has_one :raw_payload, through: :ingestion_record

  normalizes :source_key, with: -> { _1.strip.downcase }
  normalizes :transport, with: -> { _1.strip.downcase }
  normalizes :external_id, :original_url, :canonical_url, :parser_version, with: -> { _1.strip.presence }
  normalizes :presence_state, with: -> { _1.strip.downcase }
  normalizes :content_digest, :idempotency_key, with: -> { _1.strip.downcase }

  validates :source_key, presence: true, format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
  validates :transport, inclusion: { in: Acquisition::PERSISTED_TRANSPORTS }
  validates :presence_state, inclusion: { in: Acquisition::PRESENCE_STATES }
  validates :observed_at, :ingested_at, presence: true
  validates :content_digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :idempotency_key, presence: true, uniqueness: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :original_url, :canonical_url,
    format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true
  validate :provenance_links_are_consistent

  # Source observations are immutable evidence. Corrections are represented by
  # later observations or downstream interpretation, never by rewriting facts.
  def readonly?
    persisted?
  end

  private

  def provenance_links_are_consistent
    return if source_run.blank? || ingestion_record.blank?

    if ingestion_record.source_run_id != source_run_id
      errors.add(:ingestion_record, "must belong to the same source run")
    end
    errors.add(:source_key, "must match the source run") if source_run.source_key != source_key
    errors.add(:transport, "must match the source run") if source_run.transport != transport
    if ingestion_record.raw_payload&.content_digest != content_digest
      errors.add(:content_digest, "must match the raw payload")
    end
  end
end
