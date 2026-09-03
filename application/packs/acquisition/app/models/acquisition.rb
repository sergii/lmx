# frozen_string_literal: true

module Acquisition
  # Acquisition transport is deliberately distinct from ingress interfaces
  # such as API, webhook, MCP, import, or manual web entry.
  TRANSPORTS = %w[
    rss
    http_api
    http_scrape
    browser_crawl
    external_agent
  ].freeze

  # Existing SourceObservation rows may contain these historical values from
  # before acquisition transport and ingress interface were separated. Models
  # accept them for backfill/replay, while the public SourceRuns API does not.
  LEGACY_INGRESS_TRANSPORTS = %w[
    webhook
    api_submission
    manual
    import
  ].freeze

  PERSISTED_TRANSPORTS = (TRANSPORTS + LEGACY_INGRESS_TRANSPORTS).freeze
  PRESENCE_STATES = %w[present missing explicitly_closed unknown].freeze
end
