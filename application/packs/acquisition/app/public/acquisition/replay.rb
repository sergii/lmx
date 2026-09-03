# frozen_string_literal: true

module Acquisition
  class Replay
    class UnsupportedSource < StandardError; end
    class ParseError < StandardError; end

    SUPPORTED_SOURCE_KEYS = %w[dou djinni work_ua robota_ua remoteok].freeze
    DEFAULT_STRATEGIES = {
      "dou" => "rss",
      "djinni" => "rss",
      "work_ua" => "http_html",
      "robota_ua" => "http_api",
      "remoteok" => "http_api"
    }.freeze
    SEMANTIC_FIELDS = %i[
      external_id original_url canonical_url observed_at source_published_at source_updated_at
      presence_state payload
    ].freeze

    class << self
      def call(source_key:, from: nil, to: nil, apply: false, limit: nil)
        new(source_key:, from:, to:, apply:, limit:).call
      end
    end

    def initialize(source_key:, from:, to:, apply:, limit:)
      @source_key = source_key.to_s.strip.downcase
      @from = normalize_optional_time(from)
      @to = normalize_optional_time(to)
      @apply = ActiveModel::Type::Boolean.new.cast(apply)
      @limit = normalize_limit(limit)

      SourceRegistry.fetch(@source_key)
      raise UnsupportedSource, "Replay is not implemented for #{@source_key}" unless SUPPORTED_SOURCE_KEYS.include?(@source_key)
      raise ArgumentError, "from must be before or equal to to" if @from && @to && @from > @to
    end

    def call
      plans = raw_payload_scope.map { plan_raw_payload(_1) }
      persisted_count = apply ? persist!(plans) : 0

      deep_freeze(
        {
          source_key:,
          mode: apply ? "apply" : "dry_run",
          from: from&.iso8601,
          to: to&.iso8601,
          limit:,
          selected_raw_payloads: plans.size,
          summary: aggregate_counts(plans).merge(persisted: persisted_count),
          raw_payloads: plans.map { public_plan(_1) }
        }.compact
      )
    end

    private

    attr_reader :source_key, :from, :to, :apply, :limit

    def raw_payload_scope
      scope = RawPayload.where(source_run: SourceRun.where(source_key:)).order(:captured_at, :id)
      scope = scope.where("captured_at >= ?", from) if from
      scope = scope.where("captured_at <= ?", to) if to
      scope = scope.limit(limit) if limit
      scope.includes(:source_run, ingestion_records: :source_observations)
    end

    def plan_raw_payload(raw)
      strategy = strategy_for(raw)
      parser_version = parser_versions.fetch(strategy)
      vacancies = parse(raw, strategy)
      vacancies = filter_remote_ok(vacancies, raw) if source_key == "remoteok"
      baseline = baseline_by_identity(raw)
      proposals = vacancies.map { proposal_for(_1, raw, strategy, parser_version, baseline) }
      proposal_by_identity = proposals.index_by { identity_for(_1) }
      changes = proposals.map { diff_for(_1, baseline[identity_for(_1)]) }

      (baseline.keys - proposal_by_identity.keys).each do |identity|
        changes << {
          identity:,
          status: "removed",
          changed_fields: [ "presence" ]
        }
      end

      {
        raw_payload: raw,
        strategy:,
        parser_version:,
        proposals:,
        changes:,
        counts: count_changes(changes)
      }
    rescue ParseError
      raise
    rescue StandardError => error
      raise ParseError,
        "Replay failed for #{source_key} raw payload #{raw.typed_id}: #{error.class}: #{error.message}"
    end

    def parse(raw, strategy)
      parser_for(strategy).parse(raw.body, base_url: SourceRegistry.fetch(source_key).fetch("base_url"))
    rescue StandardError => error
      raise ParseError,
        "Replay failed for #{source_key} raw payload #{raw.typed_id}: #{error.class}: #{error.message}"
    end

    def parser_for(strategy)
      case source_key
      when "dou"
        strategy == "rss" ? Dou::FeedParser.new : Dou::ListingParser.new
      when "djinni" then Djinni::FeedParser.new
      when "work_ua" then WorkUa::ListingParser.new
      when "robota_ua" then RobotaUa::ApiParser.new
      when "remoteok" then RemoteOk::ApiParser.new
      end
    end

    def source_module
      case source_key
      when "dou" then Dou
      when "djinni" then Djinni
      when "work_ua" then WorkUa
      when "robota_ua" then RobotaUa
      when "remoteok" then RemoteOk
      end
    end

    def parser_versions
      source_module.const_get(:PARSER_VERSIONS)
    end

    def adapter_versions
      source_module.const_get(:ADAPTER_VERSIONS)
    end

    def collector_class
      source_module.const_get(:Collector)
    end

    def strategy_for(raw)
      strategy = raw.provenance["strategy"].presence || raw.source_run.provenance["strategy"].presence
      strategy ||= DEFAULT_STRATEGIES.fetch(source_key)
      return strategy if parser_versions.key?(strategy)

      raise UnsupportedSource, "Replay strategy #{strategy.inspect} is not implemented for #{source_key}"
    end

    def proposal_for(vacancy, raw, strategy, parser_version, baseline)
      identity = vacancy.external_id.to_s.strip.presence || vacancy.url.to_s.strip
      previous = baseline[identity]
      ingestion = raw.ingestion_records.min_by(&:id)

      {
        source_run: raw.source_run,
        raw_payload: raw,
        observed_at: previous&.observed_at || raw.captured_at,
        external_id: vacancy.external_id,
        original_url: vacancy.url,
        canonical_url: vacancy.url,
        source_published_at: vacancy.respond_to?(:published_at) ? vacancy.published_at : nil,
        source_updated_at: nil,
        presence_state: "present",
        adapter_version: ingestion&.adapter_version || raw.source_run.adapter_version || adapter_versions.fetch(strategy),
        parser_version:,
        ingress_interface: ingestion&.ingress_interface,
        payload: vacancy_payload(vacancy),
        ingestion_provenance: ingestion&.provenance || replay_ingestion_provenance(raw, strategy),
        metadata: replay_metadata(raw, strategy, parser_version)
      }
    end

    def vacancy_payload(vacancy)
      common = {
        "record_type" => "job_posting",
        "source" => source_key,
        "source_record_key" => vacancy.external_id,
        "url" => vacancy.url,
        "title" => vacancy.title
      }

      details = case source_key
      when "dou"
        {
          "company_name" => optional(vacancy, :company_name),
          "location_text" => optional(vacancy, :location_text),
          "summary" => optional(vacancy, :summary),
          "listed_at_text" => optional(vacancy, :listed_at_text),
          "published_at" => optional(vacancy, :published_at)&.iso8601
        }
      when "djinni"
        {
          "summary" => optional(vacancy, :summary),
          "published_at" => optional(vacancy, :published_at)&.iso8601
        }
      when "work_ua"
        {
          "company_name" => optional(vacancy, :company_name),
          "location_text" => optional(vacancy, :location_text)
        }
      when "robota_ua"
        {
          "company_name" => optional(vacancy, :company_name),
          "location_text" => optional(vacancy, :location_text),
          "summary" => optional(vacancy, :summary),
          "published_at" => optional(vacancy, :published_at)&.iso8601
        }
      when "remoteok"
        {
          "apply_url" => optional(vacancy, :apply_url),
          "company_name" => optional(vacancy, :company_name),
          "location_text" => optional(vacancy, :location_text),
          "summary" => optional(vacancy, :summary),
          "published_at" => optional(vacancy, :published_at)&.iso8601,
          "tags" => optional(vacancy, :tags),
          "salary_min" => optional(vacancy, :salary_min),
          "salary_max" => optional(vacancy, :salary_max)
        }
      end

      common.merge(details).compact
    end

    def optional(value, method_name)
      value.public_send(method_name) if value.respond_to?(method_name)
    end

    def replay_ingestion_provenance(raw, strategy)
      provenance = {
        "source" => source_key,
        "request_url" => raw.provenance["request_url"].presence || raw.source_uri,
        "strategy" => strategy
      }
      if source_key == "remoteok"
        provenance["search"] = remote_ok_search(raw)
        provenance["search_mode"] = "local_filter"
      end
      provenance.compact
    end

    def replay_metadata(raw, strategy, parser_version)
      metadata = {
        "evidence_kind" => collector_class.const_get(:EVIDENCE_KINDS).fetch(strategy),
        "extraction_method" => parser_version,
        "strategy" => strategy
      }
      if source_key == "remoteok"
        metadata["search"] = remote_ok_search(raw)
        metadata["search_mode"] = "local_filter"
      end
      metadata.compact
    end

    def remote_ok_search(raw)
      raw.provenance["search"].presence || raw.source_run.provenance["search"].presence
    end

    def filter_remote_ok(vacancies, raw)
      search = remote_ok_search(raw)
      return vacancies unless search

      terms = search.downcase.split(/\s+/)
      vacancies.select do |vacancy|
        haystack = [
          optional(vacancy, :title),
          optional(vacancy, :company_name),
          optional(vacancy, :location_text),
          optional(vacancy, :summary),
          *Array(optional(vacancy, :tags))
        ].compact.join(" ").downcase
        terms.all? { haystack.include?(_1) }
      end
    end

    def baseline_by_identity(raw)
      raw.ingestion_records.flat_map(&:source_observations).group_by { identity_for(_1) }.transform_values do |observations|
        observations.max_by { [ _1.ingested_at || _1.created_at, _1.id ] }
      end
    end

    def identity_for(value)
      external_id = value.is_a?(Hash) ? value[:external_id] : value.external_id
      canonical_url = value.is_a?(Hash) ? value[:canonical_url] : value.canonical_url
      original_url = value.is_a?(Hash) ? value[:original_url] : value.original_url
      external_id.to_s.strip.presence || canonical_url.to_s.strip.presence || original_url.to_s.strip
    end

    def diff_for(proposal, previous)
      return { identity: identity_for(proposal), status: "added", changed_fields: [] } unless previous

      previous_snapshot = semantic_snapshot(previous)
      proposal_snapshot = semantic_snapshot(proposal)
      changed_fields = changed_fields(previous_snapshot, proposal_snapshot)
      {
        identity: identity_for(proposal),
        status: changed_fields.empty? ? "unchanged" : "changed",
        changed_fields:
      }
    end

    def semantic_snapshot(value)
      if value.is_a?(Hash)
        SEMANTIC_FIELDS.to_h { [ _1, canonicalize(value[_1]) ] }
      else
        SEMANTIC_FIELDS.to_h { [ _1, canonicalize(value.public_send(_1)) ] }
      end
    end

    def changed_fields(previous, current)
      SEMANTIC_FIELDS.filter_map do |field|
        next if previous[field] == current[field]

        field.to_s
      end
    end

    def count_changes(changes)
      %w[added changed unchanged removed].to_h do |status|
        [ status.to_sym, changes.count { _1.fetch(:status) == status } ]
      end
    end

    def aggregate_counts(plans)
      plans.each_with_object({ added: 0, changed: 0, unchanged: 0, removed: 0 }) do |plan, counts|
        plan.fetch(:counts).each { |key, value| counts[key] += value }
      end
    end

    def persist!(plans)
      persisted = 0
      ApplicationRecord.transaction do
        plans.each do |plan|
          plan.fetch(:proposals).each do |proposal|
            observation = RecordSourceObservation.call(**proposal)
            persisted += 1 if observation.previously_new_record?
          end
        end
      end
      persisted
    end

    def public_plan(plan)
      raw = plan.fetch(:raw_payload)
      {
        raw_payload_id: raw.typed_id,
        source_run_id: raw.source_run.typed_id,
        captured_at: raw.captured_at.iso8601,
        strategy: plan.fetch(:strategy),
        parser_version: plan.fetch(:parser_version),
        counts: plan.fetch(:counts),
        changes: plan.fetch(:changes)
      }
    end

    def normalize_optional_time(value)
      return nil if value.blank?

      time = value.respond_to?(:in_time_zone) ? value.in_time_zone : Time.zone.parse(value.to_s)
      time || raise(ArgumentError, "invalid time value: #{value.inspect}")
    rescue ArgumentError
      raise ArgumentError, "invalid time value: #{value.inspect}"
    end

    def normalize_limit(value)
      return nil if value.blank?

      normalized = Integer(value)
      raise ArgumentError, "limit must be positive" unless normalized.positive?

      normalized
    rescue ArgumentError, TypeError
      raise ArgumentError, "limit must be a positive integer"
    end

    def canonicalize(value)
      case value
      when Hash
        value.to_h.transform_keys(&:to_s).sort.to_h.transform_values { canonicalize(_1) }
      when Array
        value.map { canonicalize(_1) }
      when Time, ActiveSupport::TimeWithZone
        value.iso8601(6)
      else
        value
      end
    end

    def deep_freeze(value)
      case value
      when Hash
        value.each { |key, item| deep_freeze(key); deep_freeze(item) }
      when Array
        value.each { deep_freeze(_1) }
      end
      value.freeze
    end
  end
end
