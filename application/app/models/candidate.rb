# frozen_string_literal: true

class Candidate < ApplicationRecord
  include TypedId
  include OrganizationScoped

  uses_typed_id "candidate"


  CONSENT_STATUSES = %w[unknown granted withdrawn].freeze
  ENGLISH_LEVELS = %w[beginner intermediate upper_intermediate advanced native].freeze
  LEGACY_ENGLISH_LEVEL_TO_CEFR = {
    "beginner" => "a1",
    "intermediate" => "b1",
    "upper_intermediate" => "b2",
    "advanced" => "c1",
    "native" => "c2"
  }.freeze

  validates :first_name, :last_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :consent_status, inclusion: { in: CONSENT_STATUSES }
  validates :english_level, inclusion: { in: ENGLISH_LEVELS }, allow_blank: true

  normalizes :email, with: -> { _1.strip.downcase.presence }

  has_many :applications, dependent: :restrict_with_error
  has_many :language_proficiencies, dependent: :restrict_with_error
  has_many :meetings, dependent: :restrict_with_error
  has_many :interviews, dependent: :restrict_with_error

  def english_proficiency
    language_proficiencies.find { _1.language_code == "en" }
  end

  def english_proficiency_level
    english_proficiency&.level || LEGACY_ENGLISH_LEVEL_TO_CEFR[english_level]
  end
end
