# frozen_string_literal: true

module Integration
  module Read
    module Ports
      class Result
        attr_reader :data, :provenance

        def initialize(data:, provenance: {})
          unless provenance.is_a?(Hash)
            raise Error::ContractViolation.new("provenance must be an object")
          end

          @data = data
          @provenance = provenance.dup.freeze
          freeze
        end
      end

      class Query
        def call(_query)
          raise Error::NotImplemented
        end
      end

      class Authorization
        def authorize(_query)
          raise Error::NotImplemented, "Read authorization port is not implemented"
        end
      end

      class CapabilityResolver
        def resolve(_context)
          raise Error::NotImplemented, "Read capability resolver is not implemented"
        end
      end

      class CredentialSource
        def resolve(_context)
          raise Error::NotImplemented, "Read credential source is not implemented"
        end
      end

      class WorkspaceScope
        def call(_context, &_block)
          raise Error::NotImplemented, "Read workspace scope is not implemented"
        end
      end
    end
  end
end
