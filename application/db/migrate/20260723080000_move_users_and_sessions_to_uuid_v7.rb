# frozen_string_literal: true

class MoveUsersAndSessionsToUuidV7 < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :uuid_id, :uuid, default: -> { "uuidv7()" }, null: false
    add_index :users, :uuid_id, unique: true

    add_column :sessions, :uuid_id, :uuid, default: -> { "uuidv7()" }, null: false
    add_column :sessions, :user_uuid_id, :uuid
    add_column :memberships, :user_uuid_id, :uuid
    add_column :applications, :sourced_by_uuid_id, :uuid
    add_column :application_stage_events, :moved_by_uuid_id, :uuid

    execute <<~SQL
      UPDATE sessions SET user_uuid_id = users.uuid_id FROM users WHERE sessions.user_id = users.id;
      UPDATE memberships SET user_uuid_id = users.uuid_id FROM users WHERE memberships.user_id = users.id;
      UPDATE applications SET sourced_by_uuid_id = users.uuid_id FROM users WHERE applications.sourced_by_id = users.id;
      UPDATE application_stage_events SET moved_by_uuid_id = users.uuid_id FROM users WHERE application_stage_events.moved_by_id = users.id;
    SQL

    remove_foreign_key :sessions, :users
    remove_foreign_key :memberships, :users
    remove_foreign_key :applications, column: :sourced_by_id
    remove_foreign_key :application_stage_events, column: :moved_by_id
    remove_index :memberships, %i[user_id organization_id]

    remove_column :sessions, :user_id
    rename_column :sessions, :user_uuid_id, :user_id
    add_index :sessions, :user_id

    remove_column :memberships, :user_id
    rename_column :memberships, :user_uuid_id, :user_id
    add_index :memberships, %i[user_id organization_id], unique: true

    remove_column :applications, :sourced_by_id
    rename_column :applications, :sourced_by_uuid_id, :sourced_by_id
    add_index :applications, :sourced_by_id

    remove_column :application_stage_events, :moved_by_id
    rename_column :application_stage_events, :moved_by_uuid_id, :moved_by_id
    add_index :application_stage_events, :moved_by_id

    execute "ALTER TABLE sessions DROP CONSTRAINT sessions_pkey"
    rename_column :sessions, :id, :legacy_id
    rename_column :sessions, :uuid_id, :id
    execute "ALTER TABLE sessions ADD PRIMARY KEY (id)"
    remove_column :sessions, :legacy_id
    change_column_default :sessions, :id, -> { "uuidv7()" }

    execute "ALTER TABLE users DROP CONSTRAINT users_pkey"
    rename_column :users, :id, :legacy_id
    rename_column :users, :uuid_id, :id
    execute "ALTER TABLE users ADD PRIMARY KEY (id)"
    remove_column :users, :legacy_id
    change_column_default :users, :id, -> { "uuidv7()" }

    add_foreign_key :sessions, :users
    add_foreign_key :memberships, :users
    add_foreign_key :applications, :users, column: :sourced_by_id
    add_foreign_key :application_stage_events, :users, column: :moved_by_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "UUIDv7 user and session identifiers cannot be safely converted back to integers"
  end
end
