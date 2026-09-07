# frozen_string_literal: true

class SourceObservationCatalogSync
  class << self
    def call(observation_ids:)
      Acquisition::Observations.fetch_many(observation_ids).map do |observation|
        MarketCatalog::ReconcileSourceObservation.call(observation:)
      end.freeze
    end
  end
end
