# frozen_string_literal: true

module Acquisition
  class Observations
    class NotFound < StandardError; end

    class << self
      def fetch(observation_id)
        snapshot(find_observation(observation_id))
      rescue ActiveRecord::RecordNotFound
        raise NotFound, "source observation not found"
      end

      def fetch_many(observation_ids)
        Array(observation_ids).map { fetch(_1) }.freeze
      end

      private

      def find_observation(value)
        string = value.to_s
        return SourceObservation.find_by_typed_id!(string) if string.start_with?("source_observation_")

        SourceObservation.find(string)
      end

      def snapshot(observation)
        deep_freeze(
          {
            id: observation.typed_id,
            source_key: observation.source_key,
            transport: observation.transport,
            external_id: observation.external_id,
            original_url: observation.original_url,
            canonical_url: observation.canonical_url,
            observed_at: observation.observed_at,
            ingested_at: observation.ingested_at,
            source_published_at: observation.source_published_at,
            source_updated_at: observation.source_updated_at,
            presence_state: observation.presence_state,
            parser_version: observation.parser_version,
            content_digest: observation.content_digest,
            payload: observation.payload.deep_dup,
            metadata: observation.metadata.deep_dup
          }
        )
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, nested| deep_freeze(key); deep_freeze(nested) }.freeze
        when Array
          value.each { deep_freeze(_1) }.freeze
        else
          value.freeze
        end
      end
    end
  end
end
