# frozen_string_literal: true

module Integration
  module Mcp
    module ReadTools
      DESCRIPTIONS = {
        "openings.search" => "Search job openings visible to the authorized LMX workspace.",
        "openings.get" => "Retrieve one job opening by its opaque public identifier.",
        "candidates.get" => "Retrieve one candidate by its opaque public identifier.",
        "candidates.profile" => "Retrieve the latest canonical profile version for one candidate.",
        "matches.get" => "Retrieve one versioned match assessment by its opaque public identifier.",
        "applications.get" => "Retrieve one application by its opaque public identifier."
      }.freeze

      module_function

      def all
        Read::Contracts.all.map do |contract|
          {
            name: contract.name,
            description: DESCRIPTIONS.fetch(contract.name),
            inputSchema: contract.input_schema
          }.freeze
        end.freeze
      end

      def version_for(name)
        contract = Read::Contracts.all.find { |candidate| candidate.name == name.to_s }
        contract&.version || 1
      end
    end
  end
end
