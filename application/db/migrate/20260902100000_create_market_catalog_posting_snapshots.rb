# frozen_string_literal: true

class CreateMarketCatalogPostingSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :market_catalog_posting_snapshots, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :job_posting,
        null: false,
        type: :uuid,
        foreign_key: { to_table: :market_catalog_job_postings },
        index: { name: "idx_market_snapshots_posting" }
      t.uuid :source_observation_id, null: false
      t.datetime :observed_at, null: false
      t.string :presence_state, null: false, default: "unknown"
      t.string :title
      t.string :description_fingerprint
      t.datetime :source_published_at
      t.datetime :source_updated_at
      t.jsonb :facts, null: false, default: {}
      t.string :content_digest, null: false
      t.string :normalizer_key, null: false
      t.string :normalizer_version, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :market_catalog_posting_snapshots,
      :source_observation_id,
      unique: true,
      name: "idx_market_snapshots_source_observation"
    add_index :market_catalog_posting_snapshots,
      %i[job_posting_id observed_at],
      name: "idx_market_snapshots_posting_observed"
    add_check_constraint :market_catalog_posting_snapshots,
      "presence_state IN ('present', 'missing', 'explicit_closed', 'unknown')",
      name: "market_snapshots_presence_state_check"
    add_check_constraint :market_catalog_posting_snapshots,
      "content_digest ~ '^[0-9a-f]{64}$'",
      name: "market_snapshots_content_digest_check"
  end
end
