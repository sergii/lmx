# frozen_string_literal: true

class IngestionRecord < ApplicationRecord
  include TypedId

  uses_typed_id "ingestion_record"

  belongs_to :source_run
  belongs_to :raw_payload
  has_many :source_observations, dependent: :restrict_with_exception

  normalizes :transport, with: -> { _1.strip.downcase }
  normalizes :collector_version, :adapter_version, :parser_version, with: -> { _1.strip.presence }
  normalizes :ingress_interface, with: -> { _1.strip.downcase.presence }
  normalizes :idempotency_key, with: -> { _1.strip.downcase }

  validates :transport, inclusion: { in: Acquisition::PERSISTED_TRANSPORTS }
  validates :ingress_interface, format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }, allow_blank: true
  validates :ingested_at, presence: true
  validates :idempotency_key, presence: true, uniqueness: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validate :provenance_links_are_consistent

  def readonly?
    persisted?
  end

  private

  def provenance_links_are_consistent
    return if source_run.blank? || raw_payload.blank?

    errors.add(:raw_payload, "must belong to the same source run") if raw_payload.source_run_id != source_run_id
    errors.add(:transport, "must match the source run") if transport != source_run.transport
  end
end
