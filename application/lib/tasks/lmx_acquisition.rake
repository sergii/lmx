# frozen_string_literal: true

require "json"

namespace :lmx do
  namespace :acquisition do
    desc "Acquire current DOU vacancies into durable Phase 0 evidence (RSS primary, HTML fallback)"
    task dou: :environment do
      result = Acquisition::Dou.collect(
        search: ENV["SEARCH"],
        strategy: ENV["STRATEGY"],
        run_key: ENV["RUN_KEY"],
        started_at: Time.current
      )

      puts JSON.pretty_generate(result.to_h)
    end

    desc "Acquire current Djinni vacancies into durable Phase 0 evidence (RSS primary)"
    task djinni: :environment do
      result = Acquisition::Djinni.collect(
        search: ENV["SEARCH"],
        strategy: ENV["STRATEGY"],
        run_key: ENV["RUN_KEY"],
        started_at: Time.current
      )

      puts JSON.pretty_generate(result.to_h)
    end

    desc "Acquire current Work.ua vacancies into durable Phase 0 evidence (HTML primary)"
    task work_ua: :environment do
      result = Acquisition::WorkUa.collect(
        search: ENV["SEARCH"],
        strategy: ENV["STRATEGY"],
        run_key: ENV["RUN_KEY"],
        started_at: Time.current
      )

      puts JSON.pretty_generate(result.to_h)
    end

    desc "Acquire current Robota.ua vacancies into durable Phase 0 evidence (HTTP API primary)"
    task robota_ua: :environment do
      result = Acquisition::RobotaUa.collect(
        search: ENV["SEARCH"],
        strategy: ENV["STRATEGY"],
        run_key: ENV["RUN_KEY"],
        started_at: Time.current
      )

      puts JSON.pretty_generate(result.to_h)
    end

    desc "Acquire current Remote OK vacancies into durable Phase 0 evidence (HTTP API primary)"
    task remoteok: :environment do
      result = Acquisition::RemoteOk.collect(
        search: ENV["SEARCH"],
        strategy: ENV["STRATEGY"],
        run_key: ENV["RUN_KEY"],
        started_at: Time.current
      )

      puts JSON.pretty_generate(result.to_h)
    end

    desc "Print the current Source Catalog × Search Profile acquisition plan as JSON"
    task plan: :environment do
      puts JSON.pretty_generate(Acquisition::SourcePlanner.plan.as_json)
    end

    desc "Print acquisition source health snapshots as JSON"
    task health: :environment do
      puts JSON.pretty_generate(Acquisition::SourceHealth.all.as_json)
    end

    desc "Dry-run or apply current parser logic to persisted raw acquisition evidence"
    task replay: :environment do
      source = ENV["SOURCE"].to_s.strip
      abort "Please set SOURCE (for example SOURCE=dou)." if source.empty?

      result = Acquisition::Replay.call(
        source_key: source,
        from: ENV["FROM"],
        to: ENV["TO"],
        limit: ENV["LIMIT"],
        apply: %w[1 true yes].include?(ENV["APPLY"].to_s.strip.downcase)
      )

      puts JSON.pretty_generate(result.as_json)
    end
  end
end
