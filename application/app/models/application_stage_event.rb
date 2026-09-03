# frozen_string_literal: true

class ApplicationStageEvent < ApplicationRecord
  include TypedId
  include OrganizationScoped

  uses_typed_id "stage_event"

  belongs_to :application
  belongs_to :moved_by, class_name: "User", optional: true
end
