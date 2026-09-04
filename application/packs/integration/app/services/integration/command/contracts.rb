# frozen_string_literal: true

module Integration
  module Command
    module Contracts
      MATCHES_ASSESS = Contract.new(
        name: "matches.assess",
        version: 1,
        required_capability: "assess:matches"
      )
      OPENINGS_SUBMIT = OpeningsSubmitContract.new(
        name: "openings.submit",
        version: 1,
        required_capability: "submit:openings"
      )
      ALL = [ MATCHES_ASSESS, OPENINGS_SUBMIT ].freeze

      module_function

      def all
        ALL
      end

      def fetch(name, version = 1)
        ALL.find { |contract| contract.name == name.to_s && contract.version == Integer(version) } ||
          raise(Error::Unsupported.new(details: { name: name.to_s, version: }))
      rescue ArgumentError, TypeError
        raise Error::Unsupported.new(details: { name: name.to_s, version: })
      end
    end
  end
end
