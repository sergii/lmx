# frozen_string_literal: true

module Integration
  module Read
    class Contract
      attr_reader :name, :version, :request_kind, :response_kind, :required_capability

      def initialize(name:, version:, request_kind:, response_kind:, required_capability:)
        @name = name.to_s.freeze
        @version = Integer(version)
        @request_kind = request_kind.to_sym
        @response_kind = response_kind.to_sym
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
        case request_kind
        when :search
          {
            "type" => "object",
            "properties" => {
              "query" => { "type" => "string", "minLength" => 1 },
              "filters" => { "type" => "object", "additionalProperties" => true },
              "cursor" => { "type" => "string", "minLength" => 1 },
              "limit" => { "type" => "integer", "minimum" => 1 }
            },
            "additionalProperties" => false
          }.freeze
        when :get
          {
            "type" => "object",
            "properties" => {
              "id" => { "type" => "string", "minLength" => 1 }
            },
            "required" => [ "id" ],
            "additionalProperties" => false
          }.freeze
        else
          raise Error::Unsupported.new(details: { contract: identifier, request_kind: })
        end
      end

      def normalize_input(input)
        attributes = normalize_hash(input, error_class: Error::InvalidInput, label: "input")

        case request_kind
        when :search
          normalize_search_input(attributes)
        when :get
          normalize_get_input(attributes)
        else
          raise Error::Unsupported.new(details: { contract: identifier, request_kind: })
        end
      end

      def normalize_output(data)
        attributes = normalize_hash(data, error_class: Error::ContractViolation, label: "output")

        case response_kind
        when :collection
          normalize_collection_output(attributes)
        when :resource
          deep_copy_freeze(attributes)
        else
          raise Error::ContractViolation.new(details: { contract: identifier, response_kind: })
        end
      end

      private

      def normalize_search_input(attributes)
        assert_known_keys!(attributes, %i[query filters cursor limit])

        query = optional_string(attributes[:query], :query)
        filters = attributes.fetch(:filters, {})
        unless filters.is_a?(Hash)
          raise Error::InvalidInput.new("filters must be an object", details: { field: :filters })
        end

        cursor = optional_string(attributes[:cursor], :cursor)
        limit = attributes[:limit]
        if !limit.nil? && (!limit.is_a?(Integer) || limit <= 0)
          raise Error::InvalidInput.new("limit must be a positive integer", details: { field: :limit })
        end

        deep_copy_freeze({ query:, filters:, cursor:, limit: }.compact)
      end

      def normalize_get_input(attributes)
        assert_known_keys!(attributes, [ :id ])
        id = attributes[:id]

        unless id.is_a?(String) && !id.strip.empty?
          raise Error::InvalidInput.new("id must be a non-empty opaque typed identifier", details: { field: :id })
        end

        { id: id.dup.freeze }.freeze
      end

      def normalize_collection_output(attributes)
        items = attributes[:items]
        unless items.is_a?(Array) && items.all? { |item| item.is_a?(Hash) }
          raise Error::ContractViolation.new(
            "Collection output must contain an items array of objects",
            details: { contract: identifier, field: :items }
          )
        end

        next_cursor = attributes[:next_cursor]
        if !next_cursor.nil? && (!next_cursor.is_a?(String) || next_cursor.strip.empty?)
          raise Error::ContractViolation.new(
            "next_cursor must be a non-empty string when present",
            details: { contract: identifier, field: :next_cursor }
          )
        end

        deep_copy_freeze(attributes)
      end

      def normalize_hash(value, error_class:, label:)
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

      def assert_known_keys!(attributes, allowed)
        unknown = attributes.keys - allowed
        return if unknown.empty?

        raise Error::InvalidInput.new("Unknown input fields", details: { fields: unknown, contract: identifier })
      end

      def optional_string(value, field)
        return if value.nil?
        return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

        raise Error::InvalidInput.new("#{field} must be a non-empty string when present", details: { field: })
      end

      def deep_copy_freeze(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, item), copy|
            copy[key] = deep_copy_freeze(item)
          end.freeze
        when Array
          value.map { |item| deep_copy_freeze(item) }.freeze
        when String
          value.dup.freeze
        else
          value.freeze
        end
      end
    end
  end
end
