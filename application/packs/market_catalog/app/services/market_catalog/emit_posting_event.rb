# frozen_string_literal: true

module MarketCatalog
  class EmitPostingEvent
    MESSAGE_TYPE = "delivery.telegram.job_posting"
    AGGREGATE_TYPE = "JobPosting"

    class << self
      def call(posting:, event_type:, occurred_at: Time.current, change_kinds: [])
        workspace_id = ENV["LMX_PHASE0_WORKSPACE_ID"].to_s.strip
        return if workspace_id.blank?

        Workspace::Api.with_workspace(workspace_id:) do
          aggregate_id = posting.typed_id
          data = event_data(posting, event_type:, change_kinds:)

          Platform::Reliability::Api.append_domain_event(
            event_type:,
            aggregate_type: AGGREGATE_TYPE,
            aggregate_id:,
            expected_aggregate_version: Platform::Reliability::AggregateVersion.call(
              aggregate_type: AGGREGATE_TYPE,
              aggregate_id:
            ),
            occurred_at:,
            data:,
            outbox_messages: [
              {
                message_type: MESSAGE_TYPE,
                destination: "telegram",
                payload: data.merge("event_type" => event_type)
              }
            ]
          )
        end
      end

      private

      def event_data(posting, event_type:, change_kinds:)
        {
          "job_posting_id" => posting.typed_id,
          "job_opening_id" => posting.job_opening&.typed_id,
          "source_key" => posting.source_key,
          "external_id" => posting.external_id,
          "title" => posting.title,
          "canonical_url" => posting.canonical_url,
          "application_url" => posting.application_url,
          "source_published_at" => posting.source_published_at,
          "source_updated_at" => posting.source_updated_at,
          "lifecycle_state" => posting.lifecycle_state,
          "change_kinds" => normalized_change_kinds(event_type, change_kinds)
        }.compact.freeze
      end

      def normalized_change_kinds(event_type, change_kinds)
        kinds = Array(change_kinds).filter_map { _1.to_s.strip.presence }.uniq
        return kinds.freeze if kinds.any?

        case event_type
        when "JobPostingDiscovered"
          [ "new_posting" ].freeze
        when "JobPostingUpdated"
          [ "material_posting_change" ].freeze
        else
          [].freeze
        end
      end
    end
  end
end
