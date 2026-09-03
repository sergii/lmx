# frozen_string_literal: true

module Platform
  module Reliability
    module OutboxClaims
      DEFAULT_LEASE_TIMEOUT = 5.minutes

      module_function

      def claim(message_types:, limit: 100, at: Time.current, lease_timeout: DEFAULT_LEASE_TIMEOUT)
        types = Array(message_types).map { _1.to_s.strip }.reject(&:blank?).uniq
        raise Api::InvalidInput, "message_types must contain at least one message type" if types.empty?
        raise Api::InvalidInput, "limit must be a positive integer" unless limit.is_a?(Integer) && limit.positive?

        organization_id = current_organization_id!
        stale_before = at - lease_timeout

        Platform::OutboxMessage.transaction do
          messages = Platform::OutboxMessage
            .where(organization_id:, message_type: types)
            .where(
              "(status IN (?) AND available_at <= ?) OR " \
                "(status = ? AND publishing_started_at IS NOT NULL AND publishing_started_at <= ?)",
              %w[pending failed],
              at,
              "publishing",
              stale_before
            )
            .order(:available_at, :created_at, :id)
            .limit(limit)
            .lock("FOR UPDATE SKIP LOCKED")
            .to_a

          messages.each do |message|
            message.update!(
              status: "publishing",
              attempt_count: message.attempt_count + 1,
              publishing_started_at: at,
              last_error: nil
            )
          end

          messages.map { snapshot(_1) }.freeze
        end
      end

      def current_organization_id!
        value = ActiveRecord::Base.connection.select_value(
          "SELECT current_setting('app.current_organization', true)"
        )
        raise Api::MissingWorkspace, "workspace database scope is required" if value.blank?

        value
      end
      private_class_method :current_organization_id!

      def snapshot(message)
        {
          id: TypeID.from_uuid("outbox", message.id).to_s,
          message_type: message.message_type,
          destination: message.destination,
          payload: message.payload.deep_dup.freeze,
          attempt_count: message.attempt_count
        }.freeze
      end
      private_class_method :snapshot
    end
  end
end
