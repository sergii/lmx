# frozen_string_literal: true

require "json"
require "json_schemer"
require "pathname"
require "yaml"

module Lmx
  class Configuration
    class Error < StandardError; end
    class RootNotFound < Error; end
    class InvalidDocument < Error; end

    DOCUMENTS = {
      sources: [ "config/sources.yml", "config/sources.schema.json" ],
      default_profile: [ "config/profiles/default.yml", "config/profiles.schema.json" ]
    }.freeze

    class << self
      def load!(root: nil)
        root_path = resolve_root(root)
        loaded_documents = DOCUMENTS.to_h do |name, (document_path, schema_path)|
          [ name, load_document(root_path.join(document_path), root_path.join(schema_path)) ]
        end

        @root = root_path
        @sources = deep_freeze(loaded_documents.fetch(:sources))
        @default_profile = deep_freeze(loaded_documents.fetch(:default_profile))
        self
      end

      def loaded?
        @root && @sources && @default_profile
      end

      def root
        ensure_loaded!
        @root
      end

      def sources
        ensure_loaded!
        @sources
      end

      def default_profile
        ensure_loaded!
        @default_profile
      end

      private

      def ensure_loaded!
        load! unless loaded?
      end

      def resolve_root(explicit_root)
        return validate_root(Pathname.new(explicit_root.to_s)) if explicit_root.to_s.strip != ""

        env_root = ENV["LMX_CONFIG_ROOT"]
        return validate_root(Pathname.new(env_root)) if env_root.to_s.strip != ""

        candidates = [ Rails.root.parent, Rails.root ]
        candidates << Rails.root.join("spec/fixtures/lmx_root") if Rails.env.test?

        root = candidates.map(&:expand_path).uniq.find { complete_root?(_1) }
        return root if root

        required = DOCUMENTS.values.flatten.join(", ")
        raise RootNotFound,
          "LMX configuration root not found. Set LMX_CONFIG_ROOT to a directory containing: #{required}"
      end

      def validate_root(root)
        expanded = root.expand_path
        return expanded if complete_root?(expanded)

        missing = DOCUMENTS.values.flatten.reject { expanded.join(_1).file? }
        raise RootNotFound, "Invalid LMX_CONFIG_ROOT #{expanded}: missing #{missing.join(', ')}"
      end

      def complete_root?(root)
        DOCUMENTS.values.flatten.all? { root.join(_1).file? }
      end

      def load_document(document_path, schema_path)
        document = YAML.safe_load(document_path.read, aliases: false)
        schema = JSON.parse(schema_path.read)
        errors = JSONSchemer.schema(schema).validate(document).to_a
        return document if errors.empty?

        details = errors.first(5).map do |error|
          pointer = error["data_pointer"].to_s
          pointer = "/" if pointer.empty?
          "#{pointer} #{error.fetch('type', 'invalid')}"
        end

        raise InvalidDocument, "#{document_path}: #{details.join('; ')}"
      rescue Psych::Exception, JSON::ParserError => error
        raise InvalidDocument, "#{document_path}: #{error.message}"
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each do |key, nested|
            key.freeze
            deep_freeze(nested)
          end
        when Array
          value.each { deep_freeze(_1) }
        end

        value.freeze
      end
    end
  end
end
