# frozen_string_literal: true

module Integration
  module Command
    class OpeningsSubmitContract < Contract
      REQUIRED_FIELDS = %i[title].freeze
      OPTIONAL_STRING_FIELDS = %i[
        company_name url location remote_policy compensation notes
      ].freeze
      KNOWN_FIELDS = (REQUIRED_FIELDS + OPTIONAL_STRING_FIELDS).freeze

      def input_schema
        properties = {
          "title" => string_schema,
          "company_name" => string_schema,
          "url" => string_schema,
          "location" => string_schema,
          "remote_policy" => string_schema,
          "compensation" => string_schema,
          "notes" => string_schema
        }

        {
          "type" => "object",
          "properties" => properties,
          "required" => REQUIRED_FIELDS.map(&:to_s),
          "additionalProperties" => false
        }.freeze
      end

      def normalize_input(input)
        attributes = normalize_hash(input, label: "input")
        unknown = attributes.keys - KNOWN_FIELDS
        unless unknown.empty?
          raise Error::InvalidInput.new("Unknown input fields", details: { fields: unknown, contract: identifier })
        end

        missing = REQUIRED_FIELDS.reject { |field| attributes.key?(field) }
        unless missing.empty?
          raise Error::InvalidInput.new("Missing required input fields", details: { fields: missing, contract: identifier })
        end

        normalized = { title: required_string(attributes[:title], :title) }
        OPTIONAL_STRING_FIELDS.each do |field|
          value = optional_string(attributes[field], field)
          normalized[field] = value unless value.nil?
        end

        deep_freeze(normalized)
      end

      def normalize_output(data)
        attributes = normalize_hash(data, label: "output", error_class: Error::ContractViolation)
        opening = attributes[:opening]
        posting = attributes[:posting]
        created = attributes[:created]

        validate_resource!(opening, label: "opening")
        validate_resource!(posting, label: "posting") unless posting.nil?
        unless created == true || created == false
          raise Error::ContractViolation.new(
            "Command output must contain a boolean created flag",
            details: { contract: identifier }
          )
        end

        deep_freeze(deep_copy_json(attributes, field: :output, error_class: Error::ContractViolation))
      end

      private

      def validate_resource!(value, label:)
        unless value.is_a?(Hash)
          raise Error::ContractViolation.new(
            "Command output #{label} must be an object",
            details: { contract: identifier, field: label }
          )
        end

        id = value[:id] || value["id"]
        return if id.is_a?(String) && !id.strip.empty?

        raise Error::ContractViolation.new(
          "Command output #{label} must contain a resource id",
          details: { contract: identifier, field: label }
        )
      end
    end
  end
end
