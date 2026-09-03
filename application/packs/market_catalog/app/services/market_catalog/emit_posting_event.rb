# frozen_string_literal: true

module MarketCatalog
  class EmitPostingEvent
    MESSAGE_TYPE = "delivery.telegram.job_posting"
    AGGREGATE_TYPE = "JobPosting"

    class << self
      def call(posting:, event_type:, occurred_at: Time.current)
        workspace_id = ENV["LMX_PHASE0_WORKSPACE_ID"].to_s.strip
        return if workspace_id.blank?

        Workspace::Api.with_workspace(workspace_id:) do
          aggregate_id = posting.typed_id
          data = event_data(posting)

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

      def event_data(posting)
        {
          "job_posting_id" => posting.typed_id,
          "source_key" => posting.source_key,
          "external_id" => posting.external_id,
          "title" => posting.title,
          "canonical_url" => posting.canonical_url,
          "application_url" => posting.application_url,
          "source_published_at" => posting.source_published_at,
          "source_updated_at" => posting.source_updated_at,
          "lifecycle_state" => posting.lifecycle_state
        }.compact.freeze
      end
    end
  end
end
