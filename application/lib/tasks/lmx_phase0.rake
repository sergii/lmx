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
  end
end
