# frozen_string_literal: true

class CreateIntegrationMcpOauthGrants < ActiveRecord::Migration[8.1]
  def up
    create_table :integration_mcp_oauth_grants, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.string :issuer, null: false
      t.string :subject, null: false
      t.string :client_id, null: false
      t.string :principal, null: false
      t.string :credential, null: false
      t.string :actor, null: false
      t.string :executor, null: false
      t.string :client, null: false
      t.jsonb :capabilities, null: false, default: []
      t.datetime :revoked_at
      t.string :revoked_by
      t.text :revoke_reason
      t.string :created_by, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :integration_mcp_oauth_grants,
      %i[issuer subject client_id], unique: true,
      name: "index_mcp_oauth_grants_on_external_identity"
    add_index :integration_mcp_oauth_grants, :credential, unique: true
    add_index :integration_mcp_oauth_grants, %i[organization_id revoked_at],
      name: "index_mcp_oauth_grants_on_workspace_and_revocation"

    create_table :integration_mcp_oauth_grant_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :grant, null: false, type: :uuid,
        foreign_key: { to_table: :integration_mcp_oauth_grants }
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.string :action, null: false
      t.string :managed_by, null: false
      t.text :reason
      t.jsonb :snapshot, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :integration_mcp_oauth_grant_events, %i[grant_id created_at],
      name: "index_mcp_oauth_grant_events_on_grant_and_created"
    add_index :integration_mcp_oauth_grant_events, %i[organization_id created_at],
      name: "index_mcp_oauth_grant_events_on_workspace_and_created"
  end

  def down
    drop_table :integration_mcp_oauth_grant_events
    drop_table :integration_mcp_oauth_grants
  end
end
