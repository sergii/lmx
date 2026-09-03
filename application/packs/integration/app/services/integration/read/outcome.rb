# frozen_string_literal: true

module Integration
  module Read
    class Outcome
      attr_reader :contract, :context, :data, :provenance, :error

      def self.success(contract:, context:, data:, provenance: {})
        new(contract:, context:, data:, provenance:)
      end

      def self.failure(contract:, context:, error:)
        new(contract:, context:, error:)
      end

      def initialize(contract:, context:, data: nil, provenance: {}, error: nil)
        @contract = contract.freeze
        @context = context
        @data = data
        @provenance = provenance.dup.freeze
        @error = error
        freeze
      end

      def success?
        error.nil?
      end

      def failure?
        !success?
      end

      def to_h
        base = {
          ok: success?,
          contract:,
          context: context&.response_h
        }

        if success?
          base.merge(data:, meta: { provenance: })
        else
          base.merge(error: error.to_h)
        end
      end
    end
  end
end
