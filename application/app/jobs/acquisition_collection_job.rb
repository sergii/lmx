# frozen_string_literal: true

require "net/http"
require "timeout"

class AcquisitionCollectionJob < ApplicationJob
  queue_as :acquisition

  limits_concurrency(
    key: ->(source_key, **) { "acquisition:#{source_key}" },
    duration: 30.minutes,
    on_conflict: :discard
  )

  retry_on(
    Net::OpenTimeout,
    Net::ReadTimeout,
    Timeout::Error,
    SocketError,
    wait: :polynomially_longer,
    attempts: 4
  )

  COLLECTORS = {
    "dou" => Acquisition::Dou,
    "djinni" => Acquisition::Djinni,
    "work_ua" => Acquisition::WorkUa,
    "robota_ua" => Acquisition::RobotaUa,
    "remoteok" => Acquisition::RemoteOk
  }.freeze

  def perform(source_key, search: nil)
    source_key = source_key.to_s
    collector = COLLECTORS.fetch(source_key) do
      raise ArgumentError, "unsupported acquisition source #{source_key.inspect}"
    end

    queries = explicit_or_profile_queries(source_key, search)
    results = if queries.empty?
      [ collector.collect ]
    else
      queries.map { |query| collector.collect(search: query) }
    end

    results.each do |result|
      SourceObservationCatalogSync.call(observation_ids: result.observation_ids)
    end

    queries.empty? ? results.first : results
  end

  private

  def explicit_or_profile_queries(source_key, search)
    explicit = search.to_s.strip.presence
    return [ explicit ] if explicit

    Acquisition::QueryPolicy.source_queries(source_key)
  end
end
