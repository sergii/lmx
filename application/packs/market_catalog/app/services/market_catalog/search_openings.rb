# frozen_string_literal: true

require "base64"
require "json"
require "time"

module MarketCatalog
  class SearchOpenings
    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100
    FILTER_KEYS = %i[lifecycle_state primary_company_id source_key].freeze
    SOURCE_KEY_PATTERN = /\A[a-z0-9][a-z0-9_-]*\z/
    CURSOR_VERSION = 1

    Result = Data.define(:records, :next_cursor)

    class InvalidCursor < ArgumentError; end
    class InvalidFilter < ArgumentError; end

    class << self
      def call(query: nil, filters: {}, cursor: nil, limit: nil)
        new(query:, filters:, cursor:, limit:).call
      end
    end

    def initialize(query:, filters:, cursor:, limit:)
      @query = normalize_query(query)
      @filters = normalize_filters(filters)
      @cursor = cursor.to_s.strip.presence
      @limit = normalize_limit(limit)
    end

    def call
      relation = JobOpening.all
      relation = apply_query(relation)
      relation = apply_filters(relation)
      relation = apply_cursor(relation)

      records = relation
        .order(first_seen_at: :desc, id: :desc)
        .limit(limit + 1)
        .to_a

      has_more = records.length > limit
      records = records.first(limit).freeze
      next_cursor = has_more ? encode_cursor(records.last) : nil

      Result.new(records:, next_cursor:)
    end

    private

    attr_reader :query, :filters, :cursor, :limit

    def apply_query(relation)
      return relation unless query

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      relation.where("market_catalog_job_openings.normalized_title LIKE ?", pattern)
    end

    def apply_filters(relation)
      filters.each do |key, value|
        relation = case key
        when :lifecycle_state
          relation.where(lifecycle_state: normalize_lifecycle_states(value))
        when :primary_company_id
          relation.where(primary_company_id: normalize_company_id(value))
        when :source_key
          source_key = normalize_source_key(value)
          posting_opening_ids = JobPosting.where(source_key:).where.not(job_opening_id: nil).select(:job_opening_id)
          relation.where(id: posting_opening_ids)
        else
          raise InvalidFilter, "unsupported opening filter: #{key}"
        end
      end

      relation
    end

    def apply_cursor(relation)
      return relation unless cursor

      decoded = decode_cursor(cursor)
      relation.where(
        "market_catalog_job_openings.first_seen_at < :first_seen_at OR " \
          "(market_catalog_job_openings.first_seen_at = :first_seen_at AND " \
          "market_catalog_job_openings.id < :id)",
        first_seen_at: decoded.fetch(:first_seen_at),
        id: decoded.fetch(:id)
      )
    end

    def normalize_query(value)
      value.to_s.strip.downcase.gsub(/\s+/, " ").presence
    end

    def normalize_filters(value)
      raise InvalidFilter, "filters must be a hash" unless value.is_a?(Hash)

      normalized = value.each_with_object({}) do |(key, item), result|
        normalized_key = key.to_sym
        raise InvalidFilter, "unsupported opening filter: #{normalized_key}" unless FILTER_KEYS.include?(normalized_key)

        result[normalized_key] = item
      end

      normalized.freeze
    end

    def normalize_limit(value)
      return DEFAULT_LIMIT if value.nil?

      normalized = Integer(value)
      raise ArgumentError, "limit must be between 1 and #{MAX_LIMIT}" unless normalized.between?(1, MAX_LIMIT)

      normalized
    rescue TypeError, ArgumentError => error
      raise error if error.is_a?(ArgumentError) && error.message.start_with?("limit must be")

      raise ArgumentError, "limit must be an integer between 1 and #{MAX_LIMIT}"
    end

    def normalize_lifecycle_states(value)
      states = Array(value).map { _1.to_s.strip }
      if states.empty? || states.any?(&:blank?) || (states - JobOpening::LIFECYCLE_STATES).any?
        raise InvalidFilter, "lifecycle_state must contain known opening lifecycle states"
      end

      states
    end

    def normalize_company_id(value)
      raise InvalidFilter, "primary_company_id must be present" if value.blank?

      return Company.find_by_typed_id!(value).id if value.to_s.start_with?("company_")

      value
    rescue ActiveRecord::RecordNotFound
      raise InvalidFilter, "primary_company_id does not identify a company"
    end

    def normalize_source_key(value)
      normalized = value.to_s.strip.downcase
      raise InvalidFilter, "source_key is invalid" unless SOURCE_KEY_PATTERN.match?(normalized)

      normalized
    end

    def encode_cursor(opening)
      payload = {
        "v" => CURSOR_VERSION,
        "first_seen_at" => opening.first_seen_at.iso8601(6),
        "id" => opening.id
      }

      Base64.urlsafe_encode64(JSON.generate(payload), padding: false)
    end

    def decode_cursor(value)
      payload = JSON.parse(Base64.urlsafe_decode64(value))
      raise InvalidCursor, "unsupported opening cursor version" unless payload["v"] == CURSOR_VERSION

      first_seen_at = Time.iso8601(payload.fetch("first_seen_at"))
      id = payload.fetch("id").to_s
      raise InvalidCursor, "opening cursor id is invalid" unless /\A[0-9a-f-]{36}\z/.match?(id)

      { first_seen_at:, id: }.freeze
    rescue ArgumentError, JSON::ParserError, KeyError
      raise InvalidCursor, "opening cursor is invalid"
    end
  end
end
