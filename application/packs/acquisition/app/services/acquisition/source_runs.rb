# frozen_string_literal: true

require "digest"

module Acquisition
  class SourceRuns
    class IdempotencyConflict < StandardError; end
    class InvalidTransition < StandardError; end

    class << self
      def start(
        source_key:,
        transport:,
        started_at:,
        run_key: nil,
        collector_version: nil,
        adapter_version: nil,
        parser_version: nil,
        provenance: {}
      )
        attributes = start_attributes(
          source_key:,
          transport:,
          started_at:,
          run_key:,
          collector_version:,
          adapter_version:,
          parser_version:,
          provenance:
        )

        source_run = SourceRun.find_by(idempotency_key: attributes.fetch(:idempotency_key)) ||
          create_source_run(attributes)
        return source_run if same_start?(source_run, attributes)

        raise IdempotencyConflict, "source run idempotency key belongs to different start attributes"
      end

      def succeed(source_run:, finished_at:, observed_count:, fetched_count: nil, discovered_count: nil)
        finish(
          source_run:,
          status: "succeeded",
          finished_at:,
          fetched_count:,
          discovered_count:,
          observed_count:,
          error_class: nil,
          error_message: nil,
          error_details: {}
        )
      end

      def fail(
        source_run:,
        finished_at:,
        error_class: nil,
        error_message: nil,
        error_details: {},
        fetched_count: nil,
        discovered_count: nil,
        observed_count: nil
      )
        finish(
          source_run:,
          status: "failed",
          finished_at:,
          fetched_count:,
          discovered_count:,
          observed_count:,
          error_class: error_class.to_s.strip.presence,
          error_message: error_message.to_s.strip.presence,
          error_details: canonicalize(error_details || {})
        )
      end

      private

      def start_attributes(
        source_key:,
        transport:,
        started_at:,
        run_key:,
        collector_version:,
        adapter_version:,
        parser_version:,
        provenance:
      )
        normalized_source_key = source_key.to_s.strip.downcase
        normalized_transport = transport.to_s.strip.downcase
        normalized_started_at = normalize_time(started_at)
        normalized_run_key = run_key.to_s.strip.presence
        unless Acquisition::TRANSPORTS.include?(normalized_transport)
          raise ArgumentError, "unsupported acquisition transport: #{normalized_transport}"
        end

        {
          source_key: normalized_source_key,
          transport: normalized_transport,
          status: "running",
          started_at: normalized_started_at,
          run_key: normalized_run_key,
          collector_version: collector_version.to_s.strip.presence,
          adapter_version: adapter_version.to_s.strip.presence,
          parser_version: parser_version.to_s.strip.presence,
          provenance: canonicalize(provenance || {}),
          idempotency_key: Digest::SHA256.hexdigest(
            [
              normalized_source_key,
              normalized_transport,
              normalized_run_key || normalized_started_at.iso8601(6)
            ].join("|")
          )
        }
      end

      def create_source_run(attributes)
        SourceRun.create!(attributes)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
        SourceRun.find_by(idempotency_key: attributes.fetch(:idempotency_key)) || raise(error)
      end

      def same_start?(source_run, attributes)
        %i[
          source_key
          transport
          started_at
          run_key
          collector_version
          adapter_version
          parser_version
          provenance
        ].all? { |attribute| source_run.public_send(attribute) == attributes.fetch(attribute) }
      end

      def finish(
        source_run:,
        status:,
        finished_at:,
        fetched_count:,
        discovered_count:,
        observed_count:,
        error_class:,
        error_message:,
        error_details:
      )
        source_run = resolve_source_run(source_run)
        attributes = {
          status:,
          finished_at: normalize_time(finished_at),
          fetched_count: normalize_optional_count(fetched_count),
          discovered_count: normalize_optional_count(discovered_count),
          observed_count: normalize_optional_count(observed_count),
          error_class:,
          error_message:,
          error_details:
        }

        source_run.with_lock do
          if source_run.terminal?
            return source_run if same_finish?(source_run, attributes)

            raise InvalidTransition, "source run is already terminal with different outcome attributes"
          end

          source_run.update!(attributes)
          source_run
        end
      end

      def same_finish?(source_run, attributes)
        attributes.all? { |attribute, value| source_run.public_send(attribute) == value }
      end

      def resolve_source_run(value)
        return value if value.is_a?(SourceRun)

        SourceRun.find_by_typed_id!(value)
      end

      def normalize_optional_count(value)
        value.nil? ? nil : Integer(value)
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
end
