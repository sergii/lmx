# frozen_string_literal: true

class CreatePlatformReliabilityFoundation < ActiveRecord::Migration[8.1]
  TABLES = %i[
    platform_inbox_messages
    platform_domain_events
    platform_outbox_messages
  ].freeze

  def up
    create_table :platform_inbox_messages, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :organization_id, null: false
      t.string :message_id, null: false
      t.string :command_id, null: false
      t.string :idempotency_key, null: false
      t.string :command_name, null: false
      t.integer :command_version, null: false, default: 1
      t.string :interface, null: false
      t.string :client, null: false
      t.string :principal, null: false
      t.string :credential
      t.string :actor
      t.string :executor
      t.string :correlation_id
      t.string :causation_id
      t.jsonb :payload, null: false, default: {}
      t.string :payload_digest, null: false
      t.string :payload_reference
      t.string :status, null: false, default: "received"
      t.integer :attempt_count, null: false, default: 0
      t.jsonb :result
      t.jsonb :processing_error
      t.datetime :received_at, null: false
      t.datetime :processing_started_at
      t.datetime :processed_at
      t.timestamps
    end

    add_index :platform_inbox_messages, %i[organization_id message_id], unique: true,
      name: "index_platform_inbox_on_workspace_message"
    add_index :platform_inbox_messages, %i[organization_id command_id], unique: true,
      name: "index_platform_inbox_on_workspace_command"
    add_index :platform_inbox_messages, %i[organization_id idempotency_key], unique: true,
      name: "index_platform_inbox_on_workspace_idempotency"
    add_index :platform_inbox_messages, %i[organization_id status received_at],
      name: "index_platform_inbox_on_workspace_status"

    create_table :platform_domain_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :organization_id, null: false
      t.string :event_type, null: false
      t.integer :event_version, null: false
      t.string :aggregate_type, null: false
      t.string :aggregate_id, null: false
      t.integer :aggregate_version, null: false
      t.datetime :occurred_at, null: false
      t.datetime :effective_at
      t.string :principal
      t.string :credential
      t.string :actor
      t.string :executor
      t.string :interface
      t.string :client
      t.jsonb :evidence_references, null: false, default: []
      t.string :correlation_id
      t.string :causation_id
      t.string :command_id
      t.string :idempotency_key
      t.jsonb :data, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :platform_domain_events,
      %i[organization_id aggregate_type aggregate_id aggregate_version], unique: true,
      name: "index_platform_events_on_aggregate_version"
    add_index :platform_domain_events, %i[organization_id event_type occurred_at],
      name: "index_platform_events_on_workspace_type_time"
    add_index :platform_domain_events, %i[organization_id command_id],
      name: "index_platform_events_on_workspace_command"

    create_table :platform_outbox_messages, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :organization_id, null: false
      t.uuid :domain_event_id, null: false
      t.string :message_type, null: false
      t.integer :message_version, null: false, default: 1
      t.string :destination
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.integer :attempt_count, null: false, default: 0
      t.datetime :available_at, null: false
      t.datetime :publishing_started_at
      t.datetime :published_at
      t.jsonb :last_error
      t.timestamps
    end

    add_foreign_key :platform_outbox_messages, :platform_domain_events, column: :domain_event_id
    add_index :platform_outbox_messages, %i[organization_id domain_event_id],
      name: "index_platform_outbox_on_workspace_event"
    add_index :platform_outbox_messages, %i[organization_id status available_at],
      name: "index_platform_outbox_on_workspace_delivery"
    add_index :platform_outbox_messages, %i[organization_id status publishing_started_at],
      name: "index_platform_outbox_on_workspace_claim"

    TABLES.each do |table|
      execute <<~SQL
        ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;
        CREATE POLICY organization_isolation ON #{table}
          USING (organization_id = current_setting('app.current_organization', true)::uuid)
          WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
      SQL
    end
  end

  def down
    drop_table :platform_outbox_messages
    drop_table :platform_domain_events
    drop_table :platform_inbox_messages
  end
end
