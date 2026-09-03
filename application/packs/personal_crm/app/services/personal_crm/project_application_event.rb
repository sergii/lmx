# frozen_string_literal: true

module PersonalCrm
  class ProjectApplicationEvent
    class UnsupportedEvent < StandardError; end

    class << self
      def call(event:)
        data = event.fetch(:data).deep_symbolize_keys

        case event.fetch(:event_type)
        when Api::APPLICATION_STARTED
          project_started(event:, data:)
        when Api::APPLICATION_STAGE_CHANGED
          project_stage_changed(event:, data:)
        when Api::APPLICATION_NEXT_ACTION_CHANGED
          project_next_action_changed(event:, data:)
        else
          raise UnsupportedEvent, "unsupported Personal CRM application event"
        end
      end

      private

      def project_started(event:, data:)
        projection = ApplicationProjection.find_or_initialize_by(
          organization_id: organization_uuid(event.fetch(:workspace_id)),
          application_id: data.fetch(:id)
        )
        return snapshot(projection) if projection.persisted? && projection.stream_version >= event.fetch(:aggregate_version)

        projection.assign_attributes(
          candidate_id: data.fetch(:candidate_id),
          job_opening_id: data.fetch(:job_opening_id),
          via_posting_id: data[:via_posting_id],
          stage: data.fetch(:stage),
          started_at: data.fetch(:started_at),
          applied_at: data[:applied_at],
          channel: data[:channel],
          next_action: data[:next_action],
          next_action_at: data[:next_action_at],
          metadata: data.fetch(:metadata, {}),
          last_event_id: event.fetch(:id),
          stream_version: event.fetch(:aggregate_version)
        )
        projection.save!
        snapshot(projection)
      end

      def project_stage_changed(event:, data:)
        update_existing(event:, application_id: data.fetch(:application_id)) do |projection|
          projection.stage = data.fetch(:to_stage)
          projection.applied_at ||= data[:applied_at] if data.fetch(:to_stage) == "applied"
        end
      end

      def project_next_action_changed(event:, data:)
        update_existing(event:, application_id: data.fetch(:application_id)) do |projection|
          projection.next_action = data[:next_action]
          projection.next_action_at = data[:next_action_at]
        end
      end

      def update_existing(event:, application_id:)
        projection = ApplicationProjection.find_by!(
          organization_id: organization_uuid(event.fetch(:workspace_id)),
          application_id:
        )
        return snapshot(projection) if projection.stream_version >= event.fetch(:aggregate_version)

        yield projection
        projection.last_event_id = event.fetch(:id)
        projection.stream_version = event.fetch(:aggregate_version)
        projection.save!
        snapshot(projection)
      end

      def organization_uuid(workspace_id)
        TypeID.from_string(workspace_id).uuid.to_s
      end

      def snapshot(projection)
        {
          application_id: projection.application_id,
          stream_version: projection.stream_version
        }.freeze
      end
    end
  end
end
