# frozen_string_literal: true

module Platform
  class OutboxMessage < ApplicationRecord
    self.table_name = "platform_outbox_messages"

    STATUSES = %w[pending publishing published failed].freeze

    belongs_to :domain_event, class_name: "Platform::DomainEvent"

    validates :organization_id, :message_type, :message_version, :status, :available_at, presence: true
    validates :message_version, numericality: { only_integer: true, greater_than: 0 }
    validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :status, inclusion: { in: STATUSES }
  end
end
