# frozen_string_literal: true

require "uri"

module Integration
  class McpOauthGrant < ApplicationRecord
    self.table_name = "integration_mcp_oauth_grants"

    include TypedId

    uses_typed_id "mcp_oauth_grant"

    belongs_to :organization
    has_many :events,
      class_name: "Integration::McpOauthGrantEvent",
      foreign_key: :grant_id,
      inverse_of: :grant,
      dependent: :restrict_with_error

    normalizes :subject, :client_id, :principal, :credential, :actor, :executor, :client, :created_by,
      with: -> { _1.strip.presence }
    normalizes :revoked_by, :revoke_reason, with: -> { _1.strip.presence }

    before_validation :normalize_issuer
    before_validation :normalize_capabilities

    validates :issuer, :subject, :client_id, :principal, :credential, :actor, :executor, :client,
      :created_by, presence: true
    validates :credential, uniqueness: true
    validates :capabilities, presence: true
    validates :subject, uniqueness: { scope: %i[issuer client_id] }
    validate :issuer_is_https_identifier
    validate :capabilities_are_non_empty_strings
    validate :revocation_metadata_is_consistent

    scope :active, -> { where(revoked_at: nil) }

    def active?
      revoked_at.nil?
    end

    def workspace_id
      organization.typed_id
    end

    def snapshot
      {
        "id" => typed_id,
        "workspace_id" => workspace_id,
        "issuer" => issuer,
        "subject" => subject,
        "client_id" => client_id,
        "principal" => principal,
        "credential" => credential,
        "actor" => actor,
        "executor" => executor,
        "client" => client,
        "capabilities" => capabilities,
        "revoked_at" => revoked_at&.iso8601(6),
        "revoked_by" => revoked_by,
        "revoke_reason" => revoke_reason,
        "created_by" => created_by,
        "created_at" => created_at&.iso8601(6),
        "updated_at" => updated_at&.iso8601(6)
      }.freeze
    end

    private

    def normalize_issuer
      self.issuer = issuer.to_s.strip.presence
    end

    def normalize_capabilities
      return unless capabilities.is_a?(Array)

      self.capabilities = capabilities.map { _1.to_s.strip }.reject(&:empty?).uniq.sort
    end

    def issuer_is_https_identifier
      return if issuer.blank?

      uri = URI.parse(issuer)
      valid = uri.scheme&.downcase == "https" && uri.host && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
      errors.add(:issuer, "must be an absolute HTTPS issuer without query, userinfo, or fragment") unless valid
    rescue URI::InvalidURIError
      errors.add(:issuer, "must be a valid HTTPS URI")
    end

    def capabilities_are_non_empty_strings
      unless capabilities.is_a?(Array) && capabilities.any? && capabilities.all? { _1.is_a?(String) && !_1.empty? }
        errors.add(:capabilities, "must contain non-empty strings")
      end
    end

    def revocation_metadata_is_consistent
      if revoked_at.nil?
        errors.add(:revoked_by, "must be absent while active") if revoked_by.present?
        errors.add(:revoke_reason, "must be absent while active") if revoke_reason.present?
      elsif revoked_by.blank?
        errors.add(:revoked_by, "must be present when revoked")
      end
    end
  end
end
