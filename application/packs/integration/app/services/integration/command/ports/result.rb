# frozen_string_literal: true

module Integration
  module Command
    module Ports
      class Result
        attr_reader :data, :provenance

        def initialize(data:, provenance: {})
          unless data.is_a?(Hash)
            raise Error::ContractViolation.new("command result data must be an object")
          end
          unless provenance.is_a?(Hash)
            raise Error::ContractViolation.new("command result provenance must be an object")
          end

          @data = data
          @provenance = provenance
          freeze
        end
      end
    end
  end
end
