# frozen_string_literal: true

module Platform
  class InboxMessage < ApplicationRecord
    self.table_name = "platform_inbox_messages"

    STATUSES = %w[received processing succeeded failed].freeze

    validates :organization_id, :message_id, :command_id, :idempotency_key, :command_name,
      :command_version, :interface, :client, :principal, :payload_digest, :status, :received_at,
      presence: true
    validates :command_version, numericality: { only_integer: true, greater_than: 0 }
    validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :status, inclusion: { in: STATUSES }
  end
end
