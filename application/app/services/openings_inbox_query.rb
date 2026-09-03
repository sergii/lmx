# frozen_string_literal: true

class OpeningsInboxQuery
  LIMIT = 100
  LIFECYCLE_STATES = %w[open reopened missing probably_closed closed].freeze
  SOURCE_KEY_PATTERN = /\A[a-z0-9][a-z0-9_-]*\z/
  NEW_WINDOW = 48.hours
  FACT_KEYS = {
    compensation: %w[compensation_original_text compensation_text salary_text compensation salary],
    location: %w[location_wording location_text location],
    remote_policy: %w[remote_policy_wording remote_policy remote_work remote]
  }.freeze

  class << self
    def call(**attributes)
      new(**attributes).call
    end
  end

  def initialize(workspace_id:, user_id:, query: nil, lifecycle_state: nil, source_key: nil,
    market_api: MarketCatalog::Api, talent_api: TalentProfile::Api, intelligence_api: Intelligence::Api)
    @workspace_id = workspace_id
    @user_id = user_id
    @query = query.to_s.strip.presence
    @lifecycle_state = normalize_lifecycle_state(lifecycle_state)
    @source_key = normalize_source_key(source_key)
    @market_api = market_api
    @talent_api = talent_api
    @intelligence_api = intelligence_api
    @company_names = {}
  end

  def call
    candidate = linked_candidate
    openings = search_result.fetch(:items).map { opening_props(_1, candidate:) }

    {
      openings:,
      filters: {
        query:,
        lifecycle_state:,
        source_key:
      },
      lifecycle_states: LIFECYCLE_STATES,
      candidate: candidate_props(candidate),
      summary: summary(openings)
    }
  end

  private

  attr_reader :workspace_id, :user_id, :query, :lifecycle_state, :source_key,
    :market_api, :talent_api, :intelligence_api, :company_names

  def search_result
    market_api.search_openings(
      query:,
      filters: search_filters,
      limit: LIMIT
    )
  end

  def search_filters
    {}.tap do |filters|
      filters[:lifecycle_state] = lifecycle_state if lifecycle_state
      filters[:source_key] = source_key if source_key
    end
  end

  def linked_candidate
    talent_api.fetch_candidate_for_user(user_id:)
  rescue TalentProfile::Api::NotFound
    nil
  end

  def opening_props(opening, candidate:)
    posting_contexts = posting_contexts(opening)
    assessment = latest_assessment(opening, candidate:)
    documents = fact_documents(opening, posting_contexts)

    {
      id: opening.fetch(:id),
      title: opening.fetch(:canonical_title),
      company: company_name(opening),
      lifecycle_state: opening.fetch(:lifecycle_state),
      sources: source_props(posting_contexts),
      first_seen_at: iso8601(opening[:first_seen_at]),
      last_seen_at: iso8601(opening[:last_seen_at]),
      signals: signals(opening, posting_contexts),
      compensation: fact_text(documents, FACT_KEYS.fetch(:compensation)),
      location: fact_text(documents, FACT_KEYS.fetch(:location)),
      remote_policy: fact_text(documents, FACT_KEYS.fetch(:remote_policy)),
      opportunity_score: assessment&.fetch(:opportunity_score),
      action_priority: assessment&.fetch(:action_priority),
      recommendation: assessment&.fetch(:recommendation)
    }
  end

  def posting_contexts(opening)
    opening.fetch(:job_posting_ids).filter_map do |posting_id|
      posting = market_api.fetch_posting(posting_id:)
      history = market_api.fetch_posting_history(posting_id:)
      { posting:, history: }
    rescue MarketCatalog::Api::NotFound
      nil
    end
  end

  def source_props(posting_contexts)
    posting_contexts.map do |context|
      posting = context.fetch(:posting)
      {
        key: posting.fetch(:source_key),
        url: posting[:canonical_url] || posting[:application_url]
      }
    end.uniq { _1.fetch(:key) }
  end

  def company_name(opening)
    company_id = opening[:primary_company_id]
    return nil unless company_id

    company_names[company_id] ||= market_api.fetch_company(company_id:).fetch(:canonical_name)
  rescue MarketCatalog::Api::NotFound
    nil
  end

  def latest_assessment(opening, candidate:)
    return unless candidate

    intelligence_api.fetch_latest_match(
      workspace_id:,
      candidate_id: candidate.fetch(:id),
      job_opening_id: opening.fetch(:id)
    )
  rescue Intelligence::Api::NotFound
    nil
  end

  def candidate_props(candidate)
    return unless candidate

    {
      id: candidate.fetch(:id),
      name: [ candidate[:first_name], candidate[:last_name] ].compact.join(" "),
      profile_version_id: candidate.dig(:profile_version, :id),
      profile_version_number: candidate.dig(:profile_version, :version_number)
    }
  end

  def signals(opening, posting_contexts)
    result = []
    result << "reopened" if opening.fetch(:lifecycle_state) == "reopened"
    result << "new" if opening[:first_seen_at] && opening.fetch(:first_seen_at) >= NEW_WINDOW.ago
    result << "changed" if posting_contexts.any? { materially_changed?(_1.fetch(:history)) }
    result.freeze
  end

  def materially_changed?(history)
    history.filter_map { _1[:content_digest] }.uniq.many?
  end

  def fact_documents(opening, posting_contexts)
    documents = [ opening[:metadata] ]

    posting_contexts.each do |context|
      documents << context.dig(:posting, :metadata)
      documents << context.fetch(:history).last&.fetch(:facts, nil)
    end

    documents.compact
  end

  def fact_text(documents, keys)
    documents.reverse_each do |document|
      value = find_fact(document, keys)
      formatted = format_fact(value)
      return formatted if formatted.present?
    end

    nil
  end

  def find_fact(value, keys)
    return unless value.is_a?(Hash)

    keys.each do |key|
      return value[key] if value.key?(key)
      return value[key.to_sym] if value.key?(key.to_sym)
    end

    value.each_value do |nested|
      found = find_fact(nested, keys)
      return found unless found.nil?
    end

    nil
  end

  def format_fact(value)
    case value
    when String
      value.strip.presence
    when Numeric
      value.to_s
    when TrueClass
      "Remote"
    when FalseClass
      "On-site"
    when Array
      value.filter_map { format_fact(_1) }.join(", ").presence
    when Hash
      format_fact_hash(value)
    end
  end

  def format_fact_hash(value)
    direct_value = value[:value] || value["value"] || value[:text] || value["text"] ||
      value[:original_text] || value["original_text"] || value[:label] || value["label"]
    return format_fact(direct_value) unless direct_value.nil?

    minimum = value[:min] || value["min"] || value[:minimum] || value["minimum"]
    maximum = value[:max] || value["max"] || value[:maximum] || value["maximum"]
    currency = value[:currency] || value["currency"]
    return unless minimum || maximum || currency

    range = [ minimum, maximum ].compact.join("–")
    [ range.presence, currency ].compact.join(" ").presence
  end

  def summary(openings)
    {
      visible_count: openings.length,
      assessed_count: openings.count { !_1[:opportunity_score].nil? },
      reopened_count: openings.count { _1.fetch(:lifecycle_state) == "reopened" },
      source_count: openings.flat_map { _1.fetch(:sources).map { |source| source.fetch(:key) } }.uniq.length
    }
  end

  def normalize_lifecycle_state(value)
    normalized = value.to_s.strip
    normalized if LIFECYCLE_STATES.include?(normalized)
  end

  def normalize_source_key(value)
    normalized = value.to_s.strip.downcase
    normalized if SOURCE_KEY_PATTERN.match?(normalized)
  end

  def iso8601(value)
    value&.iso8601
  end
end
