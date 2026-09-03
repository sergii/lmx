# frozen_string_literal: true

module Integration
  module Mcp
    module CommandTools
      DESCRIPTIONS = {
        "matches.assess" => "Record a new versioned match assessment from authorized analysis output."
      }.freeze

      module_function

      def all
        Command::Contracts.all.map do |contract|
          {
            name: contract.name,
            description: DESCRIPTIONS.fetch(contract.name),
            inputSchema: contract.input_schema
          }.freeze
        end.freeze
      end

      def version_for(name)
        contract = Command::Contracts.all.find { |candidate| candidate.name == name.to_s }
        contract&.version || 1
      end
    end
  end
end
