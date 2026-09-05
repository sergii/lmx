# frozen_string_literal: true

require "json"

namespace :lmx do
  namespace :phase0 do
    desc "Verify Phase 0 production readiness and exit non-zero when any gate fails"
    task check: :environment do
      result = Lmx::Phase0::Readiness.call
      puts JSON.pretty_generate(result)
      exit 1 unless result.fetch(:status) == "ready"
    end

    desc "LIVE: fetch selected local sources, persist evidence, and verify operational acceptance"
    task accept_sources: :environment do
      sources = ENV["SOURCES"].presence || Lmx::Phase0::SourceAcceptance::DEFAULT_SOURCES
      result = Lmx::Phase0::SourceAcceptance.call(source_keys: sources)

      puts JSON.pretty_generate(result)
      exit 1 unless result.fetch(:status) == "pass"
    end
  end
end
