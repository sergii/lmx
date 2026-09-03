# frozen_string_literal: true

class AuditEvent < ApplicationRecord
  include OrganizationScoped
  include TypedId

  uses_typed_id "audit_event"

  validates :action, :subject_type, :subject_id, :occurred_at, presence: true

  before_update { raise ActiveRecord::ReadOnlyRecord, "Audit events are append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Audit events are append-only" }
end
