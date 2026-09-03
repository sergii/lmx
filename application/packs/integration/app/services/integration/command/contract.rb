# frozen_string_literal: true

module Integration
  module Command
    class Contract
      REQUIRED_FIELDS = %i[
        candidate_id candidate_profile_version_id job_opening_id opening_evidence_cutoff scoring_policy_version
        processor_kind processor_key processor_version generated_at
      ].freeze
      OPTIONAL_STRING_FIELDS = %i[
        recommendation model_name model_version
      ].freeze
      OPTIONAL_NUMBER_FIELDS = %i[opportunity_score action_priority].freeze
      JSON_OBJECT_FIELDS = %i[score_details].freeze
      JSON_ARRAY_FIELDS = %i[strengths gaps risks interview_angles evidence_references].freeze
      KNOWN_FIELDS = (
        REQUIRED_FIELDS + OPTIONAL_STRING_FIELDS + OPTIONAL_NUMBER_FIELDS + JSON_OBJECT_FIELDS + JSON_ARRAY_FIELDS
      ).freeze

      attr_reader :name, :version, :required_capability

      def initialize(name:, version:, required_capability:)
        @name = name.to_s.freeze
        @version = Integer(version)
        @required_capability = required_capability.to_s.dup.freeze
        raise ArgumentError, "required_capability must be present" if @required_capability.strip.empty?

        freeze
      end

      def identifier
        "#{name}.v#{version}"
      end

      def reference
        { name:, version: }
      end

      def input_schema
        {
          "type" => "object",
          "properties" => {
            "candidate_id" => string_schema,
            "candidate_profile_version_id" => string_schema,
            "job_opening_id" => string_schema,
            "opening_evidence_cutoff" => timestamp_schema,
            "scoring_policy_version" => string_schema,
            "opportunity_score" => { "type" => "number" },
            "action_priority" => { "type" => "number" },
            "score_details" => { "type" => "object", "additionalProperties" => true },
            "strengths" => { "type" => "array" },
            "gaps" => { "type" => "array" },
            "risks" => { "type" => "array" },
            "recommendation" => string_schema,
            "interview_angles" => { "type" => "array" },
            "evidence_references" => { "type" => "array" },
            "processor_kind" => string_schema,
            "processor_key" => string_schema,
            "processor_version" => string_schema,
            "model_name" => string_schema,
            "model_version" => string_schema,
            "generated_at" => timestamp_schema
          },
          "required" => REQUIRED_FIELDS.map(&:to_s),
          "additionalProperties" => false
        }.freeze
      end

      def normalize_input(input)
        attributes = normalize_hash(input, label: "input")
        assert_known_keys!(attributes)
        assert_required_keys!(attributes)

        normalized = {}
        REQUIRED_FIELDS.each { |field| normalized[field] = required_string(attributes[field], field) }
        OPTIONAL_STRING_FIELDS.each do |field|
          value = optional_string(attributes[field], field)
          normalized[field] = value unless value.nil?
        end
        OPTIONAL_NUMBER_FIELDS.each do |field|
          value = attributes[field]
          next if value.nil?

          unless value.is_a?(Numeric)
            raise Error::InvalidInput.new("#{field} must be numeric", details: { field: })
          end
          normalized[field] = value
        end
        JSON_OBJECT_FIELDS.each do |field|
          value = attributes.fetch(field, {})
          unless value.is_a?(Hash)
            raise Error::InvalidInput.new("#{field} must be an object", details: { field: })
          end
          normalized[field] = deep_copy_json(value, field:)
        end
        JSON_ARRAY_FIELDS.each do |field|
          value = attributes.fetch(field, [])
          unless value.is_a?(Array)
            raise Error::InvalidInput.new("#{field} must be an array", details: { field: })
          end
          normalized[field] = deep_copy_json(value, field:)
        end

        deep_freeze(normalized)
      end

      def normalize_output(data)
        attributes = normalize_hash(data, label: "output", error_class: Error::ContractViolation)
        id = attributes[:id]
        unless id.is_a?(String) && !id.strip.empty?
          raise Error::ContractViolation.new("Command output must contain a resource id", details: { contract: identifier })
        end

        deep_freeze(deep_copy_json(attributes, field: :output, error_class: Error::ContractViolation))
      end

      private

      def string_schema
        { "type" => "string", "minLength" => 1 }.freeze
      end

      def timestamp_schema
        { "type" => "string", "minLength" => 1, "format" => "date-time" }.freeze
      end

      def normalize_hash(value, label:, error_class: Error::InvalidInput)
        unless value.is_a?(Hash)
          raise error_class.new("#{label} must be an object", details: { contract: identifier })
        end

        value.each_with_object({}) do |(key, item), normalized|
          unless key.is_a?(String) || key.is_a?(Symbol)
            raise error_class.new("#{label} keys must be strings or symbols", details: { contract: identifier })
          end
          normalized[key.to_sym] = item
        end
      end

      def assert_known_keys!(attributes)
        unknown = attributes.keys - KNOWN_FIELDS
        return if unknown.empty?

        raise Error::InvalidInput.new("Unknown input fields", details: { fields: unknown, contract: identifier })
      end

      def assert_required_keys!(attributes)
        missing = REQUIRED_FIELDS.reject { |field| attributes.key?(field) }
        return if missing.empty?

        raise Error::InvalidInput.new("Missing required input fields", details: { fields: missing, contract: identifier })
      end

      def required_string(value, field)
        return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

        raise Error::InvalidInput.new("#{field} must be a non-empty string", details: { field: })
      end

      def optional_string(value, field)
        return if value.nil?
        return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

        raise Error::InvalidInput.new("#{field} must be a non-empty string when present", details: { field: })
      end

      def deep_copy_json(value, field:, error_class: Error::InvalidInput)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested), copy|
            unless key.is_a?(String) || key.is_a?(Symbol)
              raise error_class.new("#{field} contains a non-string object key", details: { field: })
            end
            copy[key.to_s] = deep_copy_json(nested, field:, error_class:)
          end
        when Array
          value.map { |nested| deep_copy_json(nested, field:, error_class:) }
        when String
          value.dup
        when Numeric, TrueClass, FalseClass, NilClass
          value
        when Time, Date, DateTime, ActiveSupport::TimeWithZone
          value.iso8601
        else
          raise error_class.new("#{field} must contain JSON-compatible values", details: { field: })
        end
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, nested| key.freeze; deep_freeze(nested) }
        when Array
          value.each { deep_freeze(_1) }
        when String
          value.freeze
        end
        value.freeze
      end
    end
  end
end
