# frozen_string_literal: true

class CreateSourceObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :source_observations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :source_key, null: false
      t.string :transport, null: false
      t.string :external_id
      t.text :canonical_url
      t.datetime :observed_at, null: false
      t.string :content_digest, null: false
      t.string :idempotency_key, null: false
      t.jsonb :payload, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :source_observations, :idempotency_key, unique: true
    add_index :source_observations, %i[source_key observed_at]
    add_index :source_observations, %i[source_key external_id observed_at], name: "index_source_observations_on_source_external_observed"
  end
end
