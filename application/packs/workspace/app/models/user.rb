# frozen_string_literal: true

class User < ApplicationRecord
  include TypedId

  uses_typed_id "user"

  has_secure_password

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end

  generates_token_for :password_reset, expires_in: 20.minutes do
    password_salt.last(10)
  end

  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships
  has_many :sent_workspace_invitations, class_name: "WorkspaceInvitation", foreign_key: :invited_by_id, dependent: :destroy
  has_many :created_tasks, class_name: "Task", foreign_key: :created_by_id, dependent: :destroy
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assigned_to_id, dependent: :destroy
  has_many :client_decisions, foreign_key: :decided_by_id, dependent: :restrict_with_error
  has_many :created_meetings, class_name: "Meeting", foreign_key: :created_by_id, dependent: :restrict_with_error

  def onboarding_completed?
    onboarding_completed_at.present?
  end

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, allow_nil: true, length: { minimum: 12 }

  normalizes :email, with: -> { _1.strip.downcase }

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  after_update if: :password_digest_previously_changed? do
    sessions.where.not(id: Current.session).delete_all
  end
end
