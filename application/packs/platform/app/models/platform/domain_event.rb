# frozen_string_literal: true

module Platform
  class DomainEvent < ApplicationRecord
    self.table_name = "platform_domain_events"

    validates :organization_id, :event_type, :event_version, :aggregate_type, :aggregate_id,
      :aggregate_version, :occurred_at, presence: true
    validates :event_version, :aggregate_version,
      numericality: { only_integer: true, greater_than: 0 }

    def readonly?
      persisted?
    end

    before_destroy { throw :abort }
  end
end
