# frozen_string_literal: true

require "digest"
require "json"

module MarketCatalog
  class RecordPostingSnapshot
    class ObservationConflict < StandardError; end

    class << self
      def call(posting_id:, source_observation_id:, observed_at:, presence_state:, normalizer_key:, normalizer_version:,
        title: nil, description_fingerprint: nil, source_published_at: nil, source_updated_at: nil,
        facts: {}, metadata: {})
        new(
          posting_id:,
          source_observation_id:,
          observed_at:,
          presence_state:,
          normalizer_key:,
          normalizer_version:,
          title:,
          description_fingerprint:,
          source_published_at:,
          source_updated_at:,
          facts:,
          metadata:
        ).call
      end
    end

    def initialize(posting_id:, source_observation_id:, observed_at:, presence_state:, normalizer_key:, normalizer_version:,
      title:, description_fingerprint:, source_published_at:, source_updated_at:, facts:, metadata:)
      @posting = find_posting(posting_id)
      @source_observation_id = observation_uuid(source_observation_id)
      @observed_at = normalize_time(observed_at)
      @presence_state = presence_state.to_s.strip.downcase
      @normalizer_key = normalizer_key.to_s.strip.downcase
      @normalizer_version = normalizer_version.to_s.strip.downcase
      @title = title.to_s.strip.gsub(/\s+/, " ").presence
      @description_fingerprint = description_fingerprint.to_s.strip.downcase.presence
      @source_published_at = normalize_time(source_published_at)
      @source_updated_at = normalize_time(source_updated_at)
      @facts = facts || {}
      @metadata = metadata || {}
      @content_digest = build_content_digest
    end

    def call
      existing = PostingSnapshot.find_by(source_observation_id:)
      return verify_existing!(existing) if existing

      PostingSnapshot.create!(attributes)
    rescue ActiveRecord::RecordNotUnique
      verify_existing!(PostingSnapshot.find_by!(source_observation_id:))
    end

    private

    attr_reader :posting, :source_observation_id, :observed_at, :presence_state,
      :normalizer_key, :normalizer_version, :title, :description_fingerprint,
      :source_published_at, :source_updated_at, :facts, :metadata, :content_digest

    def attributes
      {
        job_posting: posting,
        source_observation_id:,
        observed_at:,
        presence_state:,
        normalizer_key:,
        normalizer_version:,
        title:,
        description_fingerprint:,
        source_published_at:,
        source_updated_at:,
        facts:,
        metadata:,
        content_digest:
      }
    end

    def verify_existing!(snapshot)
      return snapshot if snapshot.job_posting_id == posting.id && snapshot.content_digest == content_digest

      raise ObservationConflict, "source observation already produced a different posting snapshot"
    end

    def build_content_digest
      payload = attributes.except(:job_posting, :content_digest).merge(job_posting_id: posting.id)
      Digest::SHA256.hexdigest(JSON.generate(canonicalize(payload)))
    end

    def canonicalize(value)
      case value
      when Hash
        value.to_h.each_with_object({}) do |(key, nested), result|
          result[key.to_s] = canonicalize(nested)
        end.sort.to_h
      when Array
        value.map { canonicalize(_1) }
      when Time, DateTime, ActiveSupport::TimeWithZone
        value.utc.iso8601(6)
      when Date
        value.iso8601
      else
        value
      end
    end

    def find_posting(value)
      value.to_s.start_with?("posting_") ? JobPosting.find_by_typed_id!(value) : JobPosting.find(value)
    end

    def observation_uuid(value)
      string = value.to_s
      return string unless string.start_with?("source_observation_")

      typed_id = TypeID.from_string(string)
      return typed_id.uuid.to_s if typed_id.prefix == "source_observation"

      raise ActiveRecord::RecordNotFound, "Invalid source_observation identifier"
    rescue TypeID::Error
      raise ActiveRecord::RecordNotFound, "Invalid source_observation identifier"
    end

    def normalize_time(value)
      return if value.blank?
      return value.in_time_zone if value.respond_to?(:in_time_zone)

      Time.zone.parse(value.to_s)
    end
  end
end
