# frozen_string_literal: true

require "digest"

module Acquisition
  class RecordIngestion
    class IdempotencyConflict < StandardError; end

    class << self
      def call(
        source_run:,
        raw_payload:,
        adapter_version: nil,
        parser_version: nil,
        ingress_interface: nil,
        ingested_at: Time.current,
        provenance: {}
      )
        new(
          source_run:,
          raw_payload:,
          adapter_version:,
          parser_version:,
          ingress_interface:,
          ingested_at:,
          provenance:
        ).call
      end
    end

    def initialize(
      source_run:,
      raw_payload:,
      adapter_version:,
      parser_version:,
      ingress_interface:,
      ingested_at:,
      provenance:
    )
      @source_run = resolve_source_run(source_run)
      @raw_payload = resolve_raw_payload(raw_payload)
      @adapter_version = adapter_version.to_s.strip.presence || @source_run.adapter_version
      @parser_version = parser_version.to_s.strip.presence || @source_run.parser_version
      @ingress_interface = ingress_interface.to_s.strip.downcase.presence
      @ingested_at = normalize_time(ingested_at)
      @provenance = canonicalize(provenance || {})
    end

    def call
      attributes = ingestion_record_attributes
      ingestion = IngestionRecord.find_by(idempotency_key: attributes.fetch(:idempotency_key))
      return ingestion if ingestion && same_ingestion_record?(ingestion, attributes)

      if ingestion
        raise IdempotencyConflict, "ingestion record idempotency key belongs to different provenance"
      end

      create_ingestion_record(attributes)
    end

    private

    attr_reader :source_run, :raw_payload, :adapter_version, :parser_version, :ingress_interface,
      :ingested_at, :provenance

    def ingestion_record_attributes
      {
        source_run:,
        raw_payload:,
        transport: source_run.transport,
        ingress_interface:,
        ingested_at:,
        collector_version: source_run.collector_version,
        adapter_version:,
        parser_version:,
        provenance:,
        idempotency_key: Digest::SHA256.hexdigest(
          [
            source_run.id,
            raw_payload.id,
            source_run.collector_version,
            adapter_version,
            parser_version,
            ingress_interface
          ].join("|")
        )
      }
    end

    def create_ingestion_record(attributes)
      IngestionRecord.create!(attributes)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      ingestion = IngestionRecord.find_by(idempotency_key: attributes.fetch(:idempotency_key))
      return ingestion if ingestion && same_ingestion_record?(ingestion, attributes)

      raise error
    end

    def same_ingestion_record?(ingestion, attributes)
      ingestion.source_run_id == source_run.id &&
        ingestion.raw_payload_id == raw_payload.id &&
        ingestion.transport == source_run.transport &&
        ingestion.ingress_interface == ingress_interface &&
        ingestion.collector_version == source_run.collector_version &&
        ingestion.adapter_version == adapter_version &&
        ingestion.parser_version == parser_version &&
        ingestion.provenance == provenance
    end

    def resolve_source_run(value)
      return value if value.is_a?(SourceRun)

      SourceRun.find_by_typed_id!(value)
    end

    def resolve_raw_payload(value)
      raw = value.is_a?(RawPayload) ? value : RawPayload.find_by_typed_id!(value)
      if raw.source_run_id != source_run.id
        raise IdempotencyConflict, "raw payload belongs to a different source run"
      end

      raw
    end

    def normalize_time(value)
      time = value.respond_to?(:in_time_zone) ? value.in_time_zone : Time.zone.parse(value.to_s)
      time || raise(ArgumentError, "invalid time value")
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
  end
end
