# frozen_string_literal: true

class CreateMarketCatalogCore < ActiveRecord::Migration[8.1]
  def change
    create_table :market_catalog_companies, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :canonical_name, null: false
      t.string :normalized_name, null: false
      t.text :website_url
      t.string :primary_domain
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :market_catalog_companies, :normalized_name, name: "idx_market_companies_normalized_name"
    add_index :market_catalog_companies, :primary_domain, name: "idx_market_companies_primary_domain"

    create_table :market_catalog_job_openings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :primary_company,
        type: :uuid,
        foreign_key: { to_table: :market_catalog_companies },
        index: { name: "idx_market_openings_primary_company" }
      t.string :canonical_title, null: false
      t.string :normalized_title, null: false
      t.string :lifecycle_state, null: false, default: "open"
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :closed_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :market_catalog_job_openings, :lifecycle_state, name: "idx_market_openings_lifecycle"
    add_index :market_catalog_job_openings,
      %i[primary_company_id normalized_title],
      name: "idx_market_openings_company_title"

    create_table :market_catalog_job_postings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :job_opening,
        type: :uuid,
        foreign_key: { to_table: :market_catalog_job_openings },
        index: { name: "idx_market_postings_opening" }
      t.references :publisher_company,
        type: :uuid,
        foreign_key: { to_table: :market_catalog_companies },
        index: { name: "idx_market_postings_publisher" }
      t.string :source_key, null: false
      t.string :external_id
      t.text :canonical_url
      t.string :canonical_url_digest
      t.text :application_url
      t.string :application_url_digest
      t.string :title, null: false
      t.string :normalized_title, null: false
      t.datetime :source_published_at
      t.datetime :source_updated_at
      t.datetime :first_seen_at, null: false
      t.datetime :last_confirmed_present_at, null: false
      t.datetime :missing_since
      t.string :lifecycle_state, null: false, default: "present"
      t.string :description_fingerprint
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :market_catalog_job_postings,
      %i[source_key external_id],
      unique: true,
      where: "external_id IS NOT NULL",
      name: "idx_market_postings_source_external"
    add_index :market_catalog_job_postings,
      %i[source_key canonical_url_digest],
      unique: true,
      where: "canonical_url_digest IS NOT NULL",
      name: "idx_market_postings_source_url_digest"
    add_index :market_catalog_job_postings,
      %i[source_key application_url_digest],
      where: "application_url_digest IS NOT NULL",
      name: "idx_market_postings_source_apply_digest"
    add_index :market_catalog_job_postings,
      %i[source_key last_confirmed_present_at],
      name: "idx_market_postings_source_last_present"
    add_index :market_catalog_job_postings, :lifecycle_state, name: "idx_market_postings_lifecycle"

    add_check_constraint :market_catalog_job_postings,
      "(external_id IS NOT NULL AND btrim(external_id) <> '') OR " \
        "(canonical_url IS NOT NULL AND btrim(canonical_url) <> '') OR " \
        "(application_url IS NOT NULL AND btrim(application_url) <> '')",
      name: "market_postings_identity_check"

    create_table :market_catalog_opening_parties, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :job_opening,
        null: false,
        type: :uuid,
        foreign_key: { to_table: :market_catalog_job_openings },
        index: { name: "idx_market_parties_opening" }
      t.references :company,
        type: :uuid,
        foreign_key: { to_table: :market_catalog_companies },
        index: { name: "idx_market_parties_company" }
      t.string :role, null: false
      t.string :party_label
      t.decimal :confidence, precision: 4, scale: 3, null: false, default: 1.0
      t.jsonb :evidence, null: false, default: []
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :market_catalog_opening_parties,
      %i[job_opening_id role company_id],
      name: "idx_market_parties_opening_role_company"
    add_check_constraint :market_catalog_opening_parties,
      "company_id IS NOT NULL OR (party_label IS NOT NULL AND btrim(party_label) <> '')",
      name: "market_parties_identity_check"
    add_check_constraint :market_catalog_opening_parties,
      "confidence >= 0 AND confidence <= 1",
      name: "market_parties_confidence_check"

    create_table :market_catalog_resolution_decisions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :decision_type, null: false
      t.references :job_posting,
        null: false,
        type: :uuid,
        foreign_key: { to_table: :market_catalog_job_postings },
        index: { name: "idx_market_resolutions_posting" }
      t.references :from_job_opening,
        type: :uuid,
        foreign_key: { to_table: :market_catalog_job_openings },
        index: { name: "idx_market_resolutions_from_opening" }
      t.references :to_job_opening,
        type: :uuid,
        foreign_key: { to_table: :market_catalog_job_openings },
        index: { name: "idx_market_resolutions_to_opening" }
      t.decimal :confidence, precision: 4, scale: 3, null: false
      t.jsonb :evidence, null: false, default: []
      t.string :resolver_key, null: false
      t.string :resolver_version, null: false
      t.datetime :decided_at, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :market_catalog_resolution_decisions,
      %i[job_posting_id decided_at],
      name: "idx_market_resolutions_posting_decided"
    add_check_constraint :market_catalog_resolution_decisions,
      "confidence >= 0 AND confidence <= 1",
      name: "market_resolutions_confidence_check"
  end
end
