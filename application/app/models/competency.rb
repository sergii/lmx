# frozen_string_literal: true

class Competency < ApplicationRecord
  include OrganizationScoped
  include TypedId

  uses_typed_id "competency"

  has_many :competency_assessments, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :organization_id }
end
