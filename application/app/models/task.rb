# frozen_string_literal: true

class Task < ApplicationRecord
  include OrganizationScoped
  include TypedId

  uses_typed_id "task"

  belongs_to :created_by, class_name: "User"
  belongs_to :assigned_to, class_name: "User"
  has_one :reminded_meeting, class_name: "Meeting", foreign_key: :reminder_task_id, dependent: :restrict_with_error

  validates :title, presence: true, length: { maximum: 240 }

  def completed?
    completed_at.present?
  end
end
