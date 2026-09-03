# frozen_string_literal: true

class LanguageProficiency < ApplicationRecord
  include OrganizationScoped
  include TypedId

  CEFR_LEVELS = {
    "a1" => "Beginner",
    "a2" => "Elementary",
    "b1" => "Intermediate",
    "b2" => "Upper-intermediate",
    "c1" => "Advanced",
    "c2" => "Proficient"
  }.freeze

  uses_typed_id "language_proficiency"

  belongs_to :candidate

  validates :language_code, format: { with: /\A[a-z]{2}\z/ }
  validates :level, inclusion: { in: CEFR_LEVELS.keys }
  validates :language_code, uniqueness: { scope: :candidate_id }
  validate :candidate_belongs_to_current_organization

  def display_name
    CEFR_LEVELS.fetch(level)
  end

  private

  def candidate_belongs_to_current_organization
    return unless candidate && candidate.organization_id != organization_id

    errors.add(:candidate, "must belong to the current organization")
  end
end
