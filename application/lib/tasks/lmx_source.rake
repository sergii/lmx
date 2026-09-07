# frozen_string_literal: true

require "json"

namespace :lmx do
  desc "Collect configured job sources and reconcile new observations into the Market Catalog"
  task source: :environment do
    supported = AcquisitionCollectionJob::COLLECTORS.keys
    requested_source = ENV["SOURCE"].to_s.strip.presence
    search = ENV["SEARCH"].to_s.strip.presence
    strict = %w[1 true yes].include?(ENV["STRICT"].to_s.strip.downcase)
    sources = requested_source ? [ requested_source ] : supported

    unknown = sources - supported
    abort "Unsupported SOURCE=#{unknown.first.inspect}. Supported: #{supported.join(', ')}" if unknown.any?

    summary = sources.map do |source_key|
      begin
        result = AcquisitionCollectionJob.new.perform(source_key, search:)
        runs = result.is_a?(Array) ? result : [ result ]

        {
          source: source_key,
          status: "succeeded",
          runs: runs.size,
          observed: runs.sum(&:observed_count),
          source_run_ids: runs.map(&:source_run_id)
        }
      rescue StandardError => error
        {
          source: source_key,
          status: "failed",
          error_class: error.class.name,
          error_message: error.message
        }
      end
    end

    puts JSON.pretty_generate(summary)

    failures = summary.select { _1.fetch(:status) == "failed" }
    if strict && failures.any?
      abort "#{failures.size} source(s) failed: #{failures.map { _1.fetch(:source) }.join(', ')}"
    end
  end
end
