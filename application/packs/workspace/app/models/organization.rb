# frozen_string_literal: true

class Organization < ApplicationRecord
  include TypedId

  uses_typed_id "org"

  has_one_attached :logo

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :candidates, dependent: :destroy
  has_many :workspace_invitations, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :client_decisions, dependent: :destroy
  has_many :language_proficiencies, dependent: :destroy
  has_many :meetings, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :onboarding_use_cases, length: { maximum: 5 }
  validate :logo_is_supported

  private

  def logo_is_supported
    return unless logo.attached?

    allowed_types = %w[image/png image/jpeg image/webp image/svg+xml]
    errors.add(:logo, "must be a PNG, JPEG, WebP, or SVG") unless logo.blob.content_type.in?(allowed_types)
    errors.add(:logo, "must be smaller than 2 MB") if logo.blob.byte_size > 2.megabytes
  end
end
