# frozen_string_literal: true

require "digest"

class RawPayload < ApplicationRecord
  include TypedId

  uses_typed_id "raw_payload"

  belongs_to :source_run
  has_many :ingestion_records, dependent: :restrict_with_exception

  normalizes :content_digest, :idempotency_key, with: -> { _1.strip.downcase }
  normalizes :content_type, :encoding, with: -> { _1.strip.presence }
  normalizes :source_uri, with: -> { _1.strip.presence }

  validates :content_digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :idempotency_key, presence: true, uniqueness: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :byte_size, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :captured_at, presence: true
  validate :body_is_present
  validate :digest_matches_body
  validate :byte_size_matches_body

  def readonly?
    persisted?
  end

  private

  def body_is_present
    errors.add(:body, "must not be nil") if body.nil?
  end

  def digest_matches_body
    return if body.nil? || content_digest.blank?
    return if Digest::SHA256.hexdigest(body.b) == content_digest

    errors.add(:content_digest, "must match the persisted raw body")
  end

  def byte_size_matches_body
    return if body.nil? || byte_size.nil? || body.bytesize == byte_size

    errors.add(:byte_size, "must match the persisted raw body")
  end
end
