# frozen_string_literal: true

require "digest"

module Acquisition
  class RecordRawPayload
    class IdempotencyConflict < StandardError; end
    class SourceRunClosed < StandardError; end

    class << self
      def call(
        source_run:,
        payload:,
        captured_at:,
        source_uri: nil,
        content_type: nil,
        encoding: nil,
        provenance: {}
      )
        new(
          source_run:,
          payload:,
          captured_at:,
          source_uri:,
          content_type:,
          encoding:,
          provenance:
        ).call
      end
    end

    def initialize(source_run:, payload:, captured_at:, source_uri:, content_type:, encoding:, provenance:)
      @source_run = resolve_source_run(source_run)
      @payload = payload
      @captured_at = normalize_time(captured_at)
      @source_uri = source_uri.to_s.strip.presence
      @content_type = content_type.to_s.strip.presence || inferred_content_type
      @encoding = encoding.to_s.strip.presence || inferred_encoding
      @provenance = canonicalize(provenance || {})
    end

    def call
      if (raw_payload = RawPayload.find_by(idempotency_key: idempotency_key))
        return raw_payload if same_raw_payload?(raw_payload)

        raise IdempotencyConflict, "raw payload idempotency key belongs to different source material"
      end

      source_run.with_lock do
        if (raw_payload = RawPayload.find_by(idempotency_key: idempotency_key))
          return raw_payload if same_raw_payload?(raw_payload)

          raise IdempotencyConflict, "raw payload idempotency key belongs to different source material"
        end

        if source_run.terminal?
          raise SourceRunClosed, "cannot attach a new raw capture to a terminal source run"
        end

        create_raw_payload
      end
    end

    private

    attr_reader :source_run, :payload, :captured_at, :source_uri, :content_type, :encoding, :provenance

    def create_raw_payload
      RawPayload.create!(
        source_run:,
        source_uri:,
        content_digest:,
        content_type:,
        encoding:,
        body: raw_body,
        byte_size: raw_body.bytesize,
        captured_at:,
        provenance:,
        idempotency_key:
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      raw_payload = RawPayload.find_by(idempotency_key:)
      return raw_payload if raw_payload && same_raw_payload?(raw_payload)

      raise error
    end

    def same_raw_payload?(raw_payload)
      raw_payload.source_run_id == source_run.id &&
        raw_payload.source_uri == source_uri &&
        raw_payload.content_digest == content_digest &&
        raw_payload.content_type == content_type &&
        raw_payload.encoding == encoding &&
        raw_payload.body == raw_body &&
        raw_payload.byte_size == raw_body.bytesize &&
        raw_payload.captured_at == captured_at &&
        raw_payload.provenance == provenance
    end

    def idempotency_key
      @idempotency_key ||= Digest::SHA256.hexdigest(
        [ source_run.id, source_uri, captured_at.iso8601(6), content_digest ].join("|")
      )
    end

    def content_digest
      @content_digest ||= Digest::SHA256.hexdigest(raw_body)
    end

    def raw_body
      @raw_body ||= (payload.is_a?(String) ? payload.dup : JSON.generate(canonicalize(payload))).b
    end

    def inferred_content_type
      payload.is_a?(String) ? "text/plain" : "application/json"
    end

    def inferred_encoding
      payload.is_a?(String) ? payload.encoding.name : Encoding::UTF_8.name
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

    def normalize_time(value)
      time = value.respond_to?(:in_time_zone) ? value.in_time_zone : Time.zone.parse(value.to_s)
      time || raise(ArgumentError, "invalid time value")
    end
  end
end
