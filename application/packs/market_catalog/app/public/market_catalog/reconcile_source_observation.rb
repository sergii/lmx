# frozen_string_literal: true

require "digest"

module MarketCatalog
  class ReconcileSourceObservation
    class InvalidObservation < StandardError; end

    NORMALIZER_VERSION = "v1"
    RESOLVER_VERSION = "v1"

    class << self
      def call(observation:)
        new(observation:).call
      end
    end

    def initialize(observation:)
      raise InvalidObservation, "observation must be an object" unless observation.is_a?(Hash)

      @observation = observation.to_h.symbolize_keys
      @payload = (@observation[:payload] || {}).to_h.stringify_keys
    end

    def call
      validate!

      ActiveRecord::Base.transaction do
        company = find_or_create_company
        posting = record_posting(company:)
        opening = posting.job_opening || create_and_link_opening(posting:, company:)
        snapshot = record_snapshot(posting:)
        ReconcilePostingLifecycle.call(posting_id: posting.typed_id)

        {
          opening_id: opening.typed_id,
          posting_id: posting.typed_id,
          posting_snapshot_id: snapshot.typed_id
        }.freeze
      end
    rescue ActiveRecord::RecordInvalid, RecordPosting::IdentityConflict,
      RecordPostingSnapshot::ObservationConflict => error
      raise InvalidObservation, error.message
    end

    private

    attr_reader :observation, :payload

    def validate!
      raise InvalidObservation, "only present job-posting observations are supported" unless presence_state == "present"
      raise InvalidObservation, "observation id is required" if observation_id.blank?
      raise InvalidObservation, "source key is required" if source_key.blank?
      raise InvalidObservation, "job-posting payload is required" unless payload["record_type"] == "job_posting"
      raise InvalidObservation, "payload source does not match observation source" if payload["source"].present? && payload["source"] != source_key
      raise InvalidObservation, "job title is required" if title.blank?
      raise InvalidObservation, "source posting identity is required" if external_id.blank? && canonical_url.blank?
    end

    def find_or_create_company
      name = optional_string(payload["company_name"])
      return if name.blank?

      normalized = name.downcase.gsub(/\s+/, " ")
      Company.find_by(normalized_name: normalized) || CreateCompany.call(
        canonical_name: name,
        metadata: {
          "first_source_key" => source_key,
          "first_source_observation_id" => observation_id
        }
      )
    rescue ActiveRecord::RecordNotUnique
      Company.find_by!(normalized_name: normalized)
    end

    def record_posting(company:)
      RecordPosting.call(
        source_key:,
        title:,
        observed_at: observation.fetch(:observed_at),
        external_id:,
        canonical_url:,
        application_url: optional_string(payload["apply_url"]),
        publisher_company_id: company&.typed_id,
        source_published_at: observation[:source_published_at],
        source_updated_at: observation[:source_updated_at],
        description_fingerprint: description_fingerprint,
        metadata: posting_metadata
      )
    end

    def create_and_link_opening(posting:, company:)
      opening = CreateOpening.call(
        canonical_title: title,
        first_seen_at: observation.fetch(:observed_at),
        primary_company_id: company&.typed_id,
        metadata: {
          "first_source_key" => source_key,
          "first_source_observation_id" => observation_id
        }
      )

      ResolvePostingOpeningLink.call(
        posting_id: posting.typed_id,
        opening_id: opening.typed_id,
        confidence: 1.0,
        evidence: [
          {
            "type" => "source_posting_identity",
            "source_key" => source_key,
            "source_observation_id" => observation_id,
            "external_id" => external_id,
            "canonical_url" => canonical_url
          }.compact
        ],
        resolver_key: "source_observation_identity",
        resolver_version: RESOLVER_VERSION,
        decided_at: observation.fetch(:observed_at),
        metadata: { "source_observation_id" => observation_id }
      )

      opening
    end

    def record_snapshot(posting:)
      RecordPostingSnapshot.call(
        posting_id: posting.typed_id,
        source_observation_id: observation_id,
        observed_at: observation.fetch(:observed_at),
        presence_state: presence_state,
        normalizer_key: "#{source_key}_job_posting",
        normalizer_version: NORMALIZER_VERSION,
        title:,
        description_fingerprint:,
        source_published_at: observation[:source_published_at],
        source_updated_at: observation[:source_updated_at],
        facts: { "source_payload" => payload },
        metadata: {
          "transport" => observation[:transport],
          "parser_version" => observation[:parser_version],
          "source_content_digest" => observation[:content_digest]
        }.compact
      )
    end

    def posting_metadata
      {
        "location_text" => optional_string(payload["location_text"]),
        "summary" => optional_string(payload["summary"]),
        "listed_at_text" => optional_string(payload["listed_at_text"]),
        "tags" => payload["tags"],
        "salary_min" => payload["salary_min"],
        "salary_max" => payload["salary_max"],
        "source_observation_id" => observation_id
      }.compact
    end

    def description_fingerprint
      summary = optional_string(payload["summary"])
      summary && Digest::SHA256.hexdigest(summary)
    end

    def observation_id
      observation[:id].to_s.strip.presence
    end

    def source_key
      observation[:source_key].to_s.strip.downcase.presence
    end

    def presence_state
      observation[:presence_state].to_s.strip.downcase
    end

    def external_id
      optional_string(observation[:external_id]) || optional_string(payload["source_record_key"])
    end

    def canonical_url
      optional_string(observation[:canonical_url]) || optional_string(payload["url"]) || optional_string(observation[:original_url])
    end

    def title
      @title ||= payload["title"].to_s.strip.gsub(/\s+/, " ").presence
    end

    def optional_string(value)
      value.to_s.strip.presence
    end
  end
end
