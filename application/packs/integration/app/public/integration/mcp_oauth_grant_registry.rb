# frozen_string_literal: true

module Integration
  module McpOauthGrantRegistry
    class Error < StandardError; end
    class InvalidInput < Error; end
    class NotFound < Error; end
    class Conflict < Error; end

    module_function

    def create_grant(
      workspace_id:,
      issuer:,
      subject:,
      client_id:,
      principal:,
      credential:,
      capabilities:,
      managed_by:,
      actor: nil,
      executor: nil,
      client: nil
    )
      with_workspace(workspace_id) do |organization|
        token_client_id = required_string(client_id, :client_id)
        normalized_principal = required_string(principal, :principal)
        manager = required_string(managed_by, :managed_by)

        grant = McpOauthGrant.create!(
          organization:,
          issuer: required_string(issuer, :issuer),
          subject: required_string(subject, :subject),
          client_id: token_client_id,
          principal: normalized_principal,
          credential: required_string(credential, :credential),
          actor: optional_string(actor) || normalized_principal,
          executor: optional_string(executor) || "oauth:#{token_client_id}",
          client: optional_string(client) || token_client_id,
          capabilities: normalize_capabilities(capabilities),
          created_by: manager
        )

        record_event!(grant, action: "created", managed_by: manager)
        grant.snapshot
      end
    rescue ActiveRecord::RecordNotUnique
      raise Conflict, "OAuth grant external identity or credential already exists"
    rescue ActiveRecord::RecordInvalid => error
      raise InvalidInput, error.record.errors.full_messages.join(", ")
    end

    def update_capabilities(workspace_id:, grant_id:, capabilities:, managed_by:)
      mutate_grant(workspace_id:, grant_id:) do |grant|
        manager = required_string(managed_by, :managed_by)
        normalized = normalize_capabilities(capabilities)
        return grant.snapshot if grant.capabilities == normalized

        grant.update!(capabilities: normalized)
        record_event!(grant, action: "capabilities_updated", managed_by: manager)
        grant.snapshot
      end
    end

    def revoke_grant(workspace_id:, grant_id:, managed_by:, reason: nil, revoked_at: Time.current)
      mutate_grant(workspace_id:, grant_id:) do |grant|
        return grant.snapshot unless grant.active?

        manager = required_string(managed_by, :managed_by)
        timestamp = revoked_at.respond_to?(:to_time) ? revoked_at.to_time : nil
        raise InvalidInput, "revoked_at must be time-like" unless timestamp

        grant.update!(
          revoked_at: timestamp,
          revoked_by: manager,
          revoke_reason: optional_string(reason)
        )
        record_event!(grant, action: "revoked", managed_by: manager, reason: optional_string(reason))
        grant.snapshot
      end
    end

    def restore_grant(workspace_id:, grant_id:, managed_by:)
      mutate_grant(workspace_id:, grant_id:) do |grant|
        return grant.snapshot if grant.active?

        manager = required_string(managed_by, :managed_by)
        grant.update!(revoked_at: nil, revoked_by: nil, revoke_reason: nil)
        record_event!(grant, action: "restored", managed_by: manager)
        grant.snapshot
      end
    end

    def list_grants(workspace_id:, include_revoked: false)
      with_workspace(workspace_id) do |organization|
        scope = McpOauthGrant.where(organization:).order(:created_at, :id)
        scope = scope.active unless include_revoked
        scope.map(&:snapshot).freeze
      end
    end

    def grant_history(workspace_id:, grant_id:)
      with_workspace(workspace_id) do |organization|
        grant = find_grant!(organization, grant_id)
        McpOauthGrantEvent.where(grant:, organization:).order(:created_at, :id).map do |event|
          {
            "id" => event.typed_id,
            "action" => event.action,
            "managed_by" => event.managed_by,
            "reason" => event.reason,
            "snapshot" => event.snapshot,
            "created_at" => event.created_at.iso8601(6)
          }.freeze
        end.freeze
      end
    end

    def mutate_grant(workspace_id:, grant_id:)
      with_workspace(workspace_id) do |organization|
        McpOauthGrant.transaction do
          grant = find_grant!(organization, grant_id)
          yield grant
        end
      end
    rescue ActiveRecord::RecordInvalid => error
      raise InvalidInput, error.record.errors.full_messages.join(", ")
    rescue ActiveRecord::StaleObjectError
      raise Conflict, "OAuth grant changed concurrently"
    end
    private_class_method :mutate_grant

    def with_workspace(workspace_id)
      Workspace::Api.with_workspace(workspace_id:) do
        organization = Current.organization
        raise Error, "workspace context did not resolve an organization" unless organization

        yield organization
      end
    rescue Workspace::Api::InvalidInput => error
      raise InvalidInput, error.message
    rescue Workspace::Api::NotFound => error
      raise NotFound, error.message
    end
    private_class_method :with_workspace

    def find_grant!(organization, grant_id)
      grant = McpOauthGrant.find_by_typed_id!(required_string(grant_id, :grant_id))
      raise ActiveRecord::RecordNotFound unless grant.organization_id == organization.id

      grant
    rescue ActiveRecord::RecordNotFound
      raise NotFound, "OAuth grant not found in workspace"
    end
    private_class_method :find_grant!

    def record_event!(grant, action:, managed_by:, reason: nil)
      McpOauthGrantEvent.create!(
        grant:,
        organization: grant.organization,
        action:,
        managed_by:,
        reason:,
        snapshot: grant.snapshot
      )
    end
    private_class_method :record_event!

    def normalize_capabilities(values)
      unless values.is_a?(Array)
        raise InvalidInput, "capabilities must be an array"
      end

      normalized = values.map { required_string(_1, :capability) }.uniq.sort
      raise InvalidInput, "capabilities must not be empty" if normalized.empty?

      normalized.freeze
    end
    private_class_method :normalize_capabilities

    def required_string(value, field)
      string = value.to_s.strip
      raise InvalidInput, "#{field} must be present" if string.empty?

      string
    end
    private_class_method :required_string

    def optional_string(value)
      string = value.to_s.strip
      string unless string.empty?
    end
    private_class_method :optional_string
  end
end
