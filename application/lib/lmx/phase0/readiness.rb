# frozen_string_literal: true

require "yaml"

module Lmx
  module Phase0
    class Readiness
      class CheckFailed < StandardError; end

      RLS_POLICY = "organization_isolation"
      PHASE0_RLS_TABLES = %w[
        candidates
        candidate_evidences
        candidate_profile_versions
        candidate_profile_version_evidences
        intelligence_match_assessments
        platform_inbox_messages
        platform_domain_events
        platform_outbox_messages
      ].freeze
      OTEL_ENDPOINT_KEYS = %w[
        OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
        OTEL_EXPORTER_OTLP_ENDPOINT
      ].freeze

      class << self
        def call(**)
          new(**).call
        end
      end

      def initialize(
        env: ENV,
        clock: -> { Time.current },
        connection: -> { ApplicationRecord.connection },
        recurring_config: -> { YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true) },
        source_catalog: Acquisition::SourceCatalog,
        source_health: Acquisition::SourceHealth,
        replay: Acquisition::Replay,
        telegram_health: Delivery::TelegramHealth,
        workspace_api: Workspace::Api,
        pending_migrations_check: -> { ActiveRecord::Migration.check_all_pending! }
      )
        @env = env
        @clock = clock
        @connection = connection
        @recurring_config = recurring_config
        @source_catalog = source_catalog
        @source_health = source_health
        @replay = replay
        @telegram_health = telegram_health
        @workspace_api = workspace_api
        @pending_migrations_check = pending_migrations_check
      end

      def call
        checks = [
          check("runtime_environment") { runtime_environment_check },
          check("database") { database_check },
          check("workspace") { workspace_check },
          check("row_level_security") { row_level_security_check },
          check("recurring_jobs") { recurring_jobs_check },
          check("source_health") { source_health_check },
          check("telegram") { telegram_check },
          check("opentelemetry") { opentelemetry_check },
          check("replay") { replay_check }
        ]

        deep_freeze(
          status: checks.all? { _1.fetch(:status) == "pass" } ? "ready" : "not_ready",
          checked_at: now.iso8601,
          checks:
        )
      end

      private

      attr_reader :env, :clock, :connection, :recurring_config, :source_catalog, :source_health,
        :replay, :telegram_health, :workspace_api, :pending_migrations_check

      def check(name)
        details = yield
        deep_freeze(name:, status: "pass", details:)
      rescue StandardError => error
        deep_freeze(
          name:,
          status: "fail",
          error: {
            class: error.class.name,
            message: error.message
          }
        )
      end

      def runtime_environment_check
        configured = Delivery::RuntimeRequirements.fetch!(
          *Delivery::RuntimeRequirements::REQUIRED_PRODUCTION_ENV,
          env:
        )

        {
          configured: configured.keys.sort
        }
      end

      def database_check
        pending_migrations_check.call
        db = connection.call
        raise CheckFailed, "database SELECT 1 failed" unless db.select_value("SELECT 1").to_i == 1

        {
          adapter: db.adapter_name,
          pending_migrations: false
        }
      end

      def workspace_check
        workspace_id = Delivery::RuntimeRequirements.fetch!("LMX_PHASE0_WORKSPACE_ID", env:).fetch(
          "LMX_PHASE0_WORKSPACE_ID"
        )
        workspace_api.with_workspace(workspace_id:) { true }

        { resolved: true }
      end

      def row_level_security_check
        rows = connection.call.select_all(<<~SQL).to_a
          SELECT
            c.relname AS table_name,
            c.relrowsecurity AS rls_enabled,
            c.relforcerowsecurity AS rls_forced,
            EXISTS (
              SELECT 1
              FROM pg_policies p
              WHERE p.schemaname = n.nspname
                AND p.tablename = c.relname
                AND p.policyname = '#{RLS_POLICY}'
            ) AS has_policy
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public'
            AND c.relkind = 'r'
        SQL
        by_table = rows.index_by { _1.fetch("table_name") }
        missing = PHASE0_RLS_TABLES.reject { by_table.key?(_1) }
        invalid = PHASE0_RLS_TABLES.filter_map do |table|
          row = by_table[table]
          next unless row
          next if db_true?(row["rls_enabled"]) && db_true?(row["rls_forced"]) && db_true?(row["has_policy"])

          table
        end

        problems = []
        problems << "missing tables: #{missing.join(', ')}" if missing.any?
        problems << "RLS/policy not enforced: #{invalid.join(', ')}" if invalid.any?
        raise CheckFailed, problems.join("; ") if problems.any?

        {
          policy: RLS_POLICY,
          tables: PHASE0_RLS_TABLES
        }
      end

      def recurring_jobs_check
        production = production_recurring_config
        jobs = active_source_ids.map do |source_key|
          key = "acquisition_#{source_key}"
          config = production[key] || raise(CheckFailed, "missing recurring job #{key}")
          expected_args = [ source_key ]
          unless config["class"] == "AcquisitionCollectionJob" && config["args"] == expected_args && config["schedule"].present?
            raise CheckFailed, "invalid recurring job #{key}"
          end

          {
            key:,
            schedule: config.fetch("schedule")
          }
        end

        delivery = production["delivery_telegram"] || raise(CheckFailed, "missing recurring job delivery_telegram")
        unless delivery["class"] == "DeliveryOutboxJob" && delivery["schedule"].present?
          raise CheckFailed, "invalid recurring job delivery_telegram"
        end

        {
          acquisition: jobs,
          delivery: {
            key: "delivery_telegram",
            schedule: delivery.fetch("schedule")
          }
        }
      end

      def source_health_check
        snapshots = source_health.all.index_by { _1.fetch(:source_key).to_s }
        sources = active_source_ids.map do |source_key|
          snapshot = snapshots[source_key] || raise(CheckFailed, "missing source health for #{source_key}")
          last_successful_at = normalize_time(snapshot[:last_successful_at])
          raise CheckFailed, "#{source_key} has never succeeded" unless last_successful_at

          age_seconds = (now - last_successful_at).round
          max_age_seconds = source_freshness_limit(source_key)
          failures = snapshot[:consecutive_failures].to_i
          if age_seconds > max_age_seconds
            raise CheckFailed, "#{source_key} is stale: last success #{age_seconds}s ago (limit #{max_age_seconds}s)"
          end
          raise CheckFailed, "#{source_key} has #{failures} consecutive failure(s)" if failures.positive?

          {
            source_key:,
            status: snapshot.fetch(:status),
            last_successful_at: last_successful_at.iso8601,
            age_seconds:,
            max_age_seconds:,
            observed_count: snapshot[:observed_count]
          }
        end

        { sources: }
      end

      def telegram_check
        result = telegram_health.check(env:)
        result.respond_to?(:to_h) ? result.to_h : { reachable: true }
      end

      def opentelemetry_check
        raise CheckFailed, "OTEL SDK is disabled" if env["OTEL_SDK_DISABLED"].to_s.casecmp("true").zero?

        exporter = env["OTEL_TRACES_EXPORTER"].to_s.strip
        endpoint_keys = OTEL_ENDPOINT_KEYS.select { env[_1].to_s.strip.present? }
        configured = endpoint_keys.any? || (exporter.present? && exporter != "none")
        raise CheckFailed, "configure an OpenTelemetry traces exporter or OTLP endpoint" unless configured

        {
          service_name: env.fetch("OTEL_SERVICE_NAME", "lmx"),
          traces_exporter: exporter.presence || "otlp",
          endpoint_configured: endpoint_keys.any?,
          configured_keys: endpoint_keys
        }
      end

      def replay_check
        sources = active_source_ids.map do |source_key|
          result = replay.call(source_key:, limit: 1, apply: false)
          selected = result.fetch(:selected_raw_payloads)
          raise CheckFailed, "#{source_key} has no persisted raw payload available for replay" unless selected.positive?

          raw_payload = result.fetch(:raw_payloads).first
          {
            source_key:,
            selected_raw_payloads: selected,
            parser_version: raw_payload&.fetch(:parser_version, nil)
          }.compact
        end

        { sources: }
      end

      def production_recurring_config
        @production_recurring_config ||= recurring_config.call.fetch("production")
      end

      def active_source_ids
        @active_source_ids ||= source_catalog.active_source_ids.map(&:to_s).freeze
      end

      def source_freshness_limit(source_key)
        schedule = production_recurring_config.dig("acquisition_#{source_key}", "schedule").to_s
        minutes = if (match = schedule.match(/\Aevery (\d+) minutes?\z/))
          match[1].to_i
        elsif schedule == "every minute"
          1
        end
        raise CheckFailed, "cannot derive freshness SLA from schedule #{schedule.inspect}" unless minutes&.positive?

        minutes * 60 * 3
      end

      def now
        @now ||= normalize_time(clock.call) || raise(CheckFailed, "clock returned no time")
      end

      def normalize_time(value)
        return if value.blank?

        value.respond_to?(:in_time_zone) ? value.in_time_zone : Time.zone.parse(value.to_s)
      end

      def db_true?(value)
        value == true || value.to_s == "t" || value.to_s == "true" || value.to_s == "1"
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
end
