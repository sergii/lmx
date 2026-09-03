# frozen_string_literal: true

module Integration
  module Read
    module Contracts
      LIST = [
        Contract.new(
          name: "openings.search",
          version: 1,
          request_kind: :search,
          response_kind: :collection,
          required_capability: "read:openings"
        ),
        Contract.new(
          name: "openings.get",
          version: 1,
          request_kind: :get,
          response_kind: :resource,
          required_capability: "read:openings"
        ),
        Contract.new(
          name: "candidates.get",
          version: 1,
          request_kind: :get,
          response_kind: :resource,
          required_capability: "read:candidates"
        ),
        Contract.new(
          name: "candidates.profile",
          version: 1,
          request_kind: :get,
          response_kind: :resource,
          required_capability: "read:candidates"
        ),
        Contract.new(
          name: "matches.get",
          version: 1,
          request_kind: :get,
          response_kind: :resource,
          required_capability: "read:matches"
        ),
        Contract.new(
          name: "applications.get",
          version: 1,
          request_kind: :get,
          response_kind: :resource,
          required_capability: "read:applications"
        )
      ].freeze

      REGISTRY = LIST.to_h { |contract| [ [ contract.name, contract.version ], contract ] }.freeze

      module_function

      def fetch(name, version = 1)
        normalized_name = name.to_s
        normalized_version = Integer(version)
        contract = REGISTRY[[ normalized_name, normalized_version ]]
        return contract if contract

        raise Error::Unsupported.new(details: { name: normalized_name, version: normalized_version })
      rescue ArgumentError, TypeError
        raise Error::InvalidInput.new("version must be an integer", details: { version: })
      end

      def all
        LIST
      end
    end
  end
end
