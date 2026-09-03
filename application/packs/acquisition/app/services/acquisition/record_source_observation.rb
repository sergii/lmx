# frozen_string_literal: true

require "digest"

module Acquisition
  class RecordSourceObservation
    class IdempotencyConflict < StandardError; end

    SourceRunClosed = RecordRawPayload::SourceRunClosed

    class << self
      def call(
        source_run:,
        observed_at:,
        payload:,
        raw_payload: nil,
        external_id: nil,
        original_url: nil,
        canonical_url: nil,
        source_published_at: nil,
        source_updated_at: nil,
        presence_state: "present",
        adapter_version: nil,
        parser_version: nil,
        ingress_interface: nil,
        source_uri: nil,
        content_type: nil,
        encoding: nil,
        captured_at: nil,
        raw_provenance: nil,
        ingestion_provenance: {},
        metadata: {}
      )
        new(
          source_run:,
          observed_at:,
          payload:,
          raw_payload: raw_payload.nil? ? payload : raw_payload,
          external_id:,
          original_url:,
          canonical_url:,
          source_published_at:,
          source_updated_at:,
          presence_state:,
          adapter_version:,
          parser_version:,
          ingress_interface:,
          source_uri:,
          content_type:,
          encoding:,
          captured_at:,
          raw_provenance:,
          ingestion_provenance:,
          metadata:
        ).call
      end
    end

    def initialize(
      source_run:,
      observed_at:,
      payload:,
      raw_payload:,
      external_id:,
      original_url:,
      canonical_url:,
      source_published_at:,
      source_updated_at:,
      presence_state:,
      adapter_version:,
      parser_version:,
      ingress_interface:,
      source_uri:,
      content_type:,
      encoding:,
      captured_at:,
      raw_provenance:,
      ingestion_provenance:,
      metadata:
    )
      @source_run = resolve_source_run(source_run)
      @observed_at = normalize_time(observed_at)
      @payload = canonicalize(payload)
      @raw_payload_input = raw_payload
      @external_id = external_id.to_s.strip.presence
      @original_url = original_url.to_s.strip.presence
      @canonical_url = canonical_url.to_s.strip.presence
      @source_published_at = normalize_optional_time(source_published_at)
      @source_updated_at = normalize_optional_time(source_updated_at)
      @presence_state = presence_state.to_s.strip.downcase
      @adapter_version = adapter_version.to_s.strip.presence || @source_run.adapter_version
      @parser_version = parser_version.to_s.strip.presence || @source_run.parser_version
      @ingress_interface = ingress_interface.to_s.strip.downcase.presence
      @source_uri = source_uri.to_s.strip.presence
      @content_type = content_type.to_s.strip.presence
      @encoding = encoding.to_s.strip.presence
      @captured_at = normalize_optional_time(captured_at)
      @raw_provenance = raw_provenance.nil? ? nil : canonicalize(raw_provenance)
      @ingestion_provenance = canonicalize(ingestion_provenance || {})
      @metadata = canonicalize(metadata || {})
    end

    def call
      raw = resolve_raw_payload
      key = observation_idempotency_key(raw)

      if (observation = SourceObservation.find_by(idempotency_key: key))
        return observation if same_observation?(observation, raw)

        raise IdempotencyConflict, "source observation idempotency key belongs to different evidence"
      end

      if source_run.terminal? && !raw_payload_input.is_a?(RawPayload)
        raise SourceRunClosed, "cannot add new evidence to a terminal source run without explicit replay input"
      end

      source_run.with_lock do
        if (observation = SourceObservation.find_by(idempotency_key: key))
          return observation if same_observation?(observation, raw)

          raise IdempotencyConflict, "source observation idempotency key belongs to different evidence"
        end

        ingestion = find_or_create_ingestion_record(raw)
        create_observation(raw, ingestion)
      end
    end

    private

    attr_reader :source_run, :observed_at, :payload, :raw_payload_input, :external_id, :original_url,
      :canonical_url, :source_published_at, :source_updated_at, :presence_state, :adapter_version,
      :parser_version, :ingress_interface, :source_uri, :content_type, :encoding, :captured_at,
      :raw_provenance, :ingestion_provenance, :metadata

    def resolve_raw_payload
      return validate_persisted_raw_payload(raw_payload_input) if raw_payload_input.is_a?(RawPayload)

      RecordRawPayload.call(
        source_run:,
        payload: raw_payload_input,
        source_uri: source_uri || original_url || canonical_url,
        content_type:,
        encoding:,
        captured_at: captured_at || observed_at,
        provenance: raw_provenance || {}
      )
    rescue RecordRawPayload::IdempotencyConflict => error
      raise IdempotencyConflict, error.message
    end

    def validate_persisted_raw_payload(raw)
      if raw.source_run_id != source_run.id
        raise IdempotencyConflict, "raw payload belongs to a different source run"
      end

      assert_optional_match(:source_uri, source_uri, raw.source_uri)
      assert_optional_match(:content_type, content_type, raw.content_type)
      assert_optional_match(:encoding, encoding, raw.encoding)
      assert_optional_match(:captured_at, captured_at, raw.captured_at)
      assert_optional_match(:raw_provenance, raw_provenance, raw.provenance)
      raw
    end

    def assert_optional_match(field, supplied, existing)
      return if supplied.nil? || supplied == existing

      raise IdempotencyConflict, "#{field} conflicts with the persisted raw payload"
    end

    def find_or_create_ingestion_record(raw)
      attributes = ingestion_record_attributes(raw)
      ingestion = IngestionRecord.find_by(idempotency_key: attributes.fetch(:idempotency_key))
      return ingestion if ingestion && same_ingestion_record?(ingestion, attributes)
      if ingestion
        raise IdempotencyConflict, "ingestion record idempotency key belongs to different provenance"
      end

      create_ingestion_record(attributes)
    end

    def create_ingestion_record(attributes)
      IngestionRecord.create!(attributes)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      ingestion = IngestionRecord.find_by(idempotency_key: attributes.fetch(:idempotency_key))
      return ingestion if ingestion && same_ingestion_record?(ingestion, attributes)

      raise error
    end

    def create_observation(raw, ingestion)
      SourceObservation.create!(observation_attributes(raw, ingestion))
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      observation = SourceObservation.find_by(idempotency_key: observation_idempotency_key(raw))
      return observation if observation && same_observation?(observation, raw)

      raise error
    end

    def ingestion_record_attributes(raw)
      {
        source_run:,
        raw_payload: raw,
        transport: source_run.transport,
        ingress_interface:,
        ingested_at: Time.current,
        collector_version: source_run.collector_version,
        adapter_version:,
        parser_version:,
        provenance: ingestion_provenance,
        idempotency_key: Digest::SHA256.hexdigest(
          [
            source_run.id,
            raw.id,
            source_run.collector_version,
            adapter_version,
            parser_version,
            ingress_interface
          ].join("|")
        )
      }
    end

    def observation_attributes(raw, ingestion)
      {
        source_run:,
        ingestion_record: ingestion,
        source_key: source_run.source_key,
        transport: source_run.transport,
        external_id:,
        original_url:,
        canonical_url:,
        observed_at:,
        ingested_at: ingestion.ingested_at,
        source_published_at:,
        source_updated_at:,
        presence_state:,
        parser_version:,
        content_digest: raw.content_digest,
        idempotency_key: observation_idempotency_key(raw),
        payload:,
        metadata:
      }
    end

    def same_ingestion_record?(ingestion, attributes)
      ingestion.source_run_id == attributes.fetch(:source_run).id &&
        ingestion.raw_payload_id == attributes.fetch(:raw_payload).id &&
        ingestion.transport == attributes.fetch(:transport) &&
        ingestion.ingress_interface == attributes[:ingress_interface] &&
        ingestion.collector_version == attributes[:collector_version] &&
        ingestion.adapter_version == attributes[:adapter_version] &&
        ingestion.parser_version == attributes[:parser_version] &&
        ingestion.provenance == attributes.fetch(:provenance)
    end

    def same_observation?(observation, raw)
      observation.source_run_id == source_run.id &&
        observation.ingestion_record&.raw_payload_id == raw.id &&
        observation.source_key == source_run.source_key &&
        observation.transport == source_run.transport &&
        observation.external_id == external_id &&
        observation.original_url == original_url &&
        observation.canonical_url == canonical_url &&
        observation.observed_at == observed_at &&
        observation.source_published_at == source_published_at &&
        observation.source_updated_at == source_updated_at &&
        observation.presence_state == presence_state &&
        observation.parser_version == parser_version &&
        observation.content_digest == raw.content_digest &&
        observation.payload == payload &&
        observation.metadata == metadata &&
        same_existing_ingestion_record?(observation.ingestion_record, raw)
    end

    def same_existing_ingestion_record?(ingestion, raw)
      ingestion &&
        ingestion.source_run_id == source_run.id &&
        ingestion.raw_payload_id == raw.id &&
        ingestion.transport == source_run.transport &&
        ingestion.ingress_interface == ingress_interface &&
        ingestion.collector_version == source_run.collector_version &&
        ingestion.adapter_version == adapter_version &&
        ingestion.parser_version == parser_version &&
        ingestion.provenance == ingestion_provenance
    end

    def observation_idempotency_key(raw)
      Digest::SHA256.hexdigest(
        [
          source_run.id,
          source_run.source_key,
          source_run.transport,
          external_id,
          original_url,
          canonical_url,
          observed_at.iso8601(6),
          parser_version,
          raw.id
        ].join("|")
      )
    end

    def canonicalize(value)
      case value
      when Hash
        value.to_h.transform_keys(&:to_s).sort.to_h.transform_values { canonicalize(_1) }
      when Array
        value.map { canonicalize(_1) }
      else
        value
      end
    end

    def resolve_source_run(value)
      return value if value.is_a?(SourceRun)

      SourceRun.find_by_typed_id!(value)
    end

    def normalize_optional_time(value)
      value.present? ? normalize_time(value) : nil
    end

    def normalize_time(value)
      time = value.respond_to?(:in_time_zone) ? value.in_time_zone : Time.zone.parse(value.to_s)
      time || raise(ArgumentError, "invalid time value")
    end
  end
end
