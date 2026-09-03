# frozen_string_literal: true

require "digest"
require "json"

class CreateAcquisitionPersistenceContract < ActiveRecord::Migration[8.1]
  def up
    create_source_runs
    create_raw_payloads
    create_ingestion_records
    extend_source_observations
    backfill_existing_source_observations
    enforce_source_observation_links
  end

  def down
    remove_index :source_observations, :ingestion_record_id
    remove_index :source_observations, %i[source_run_id observed_at]

    remove_column :source_observations, :parser_version
    remove_column :source_observations, :presence_state
    remove_column :source_observations, :ingested_at
    remove_column :source_observations, :source_updated_at
    remove_column :source_observations, :source_published_at
    remove_column :source_observations, :original_url
    remove_reference :source_observations, :ingestion_record, foreign_key: true
    remove_reference :source_observations, :source_run, foreign_key: true

    drop_table :ingestion_records
    drop_table :raw_payloads
    drop_table :source_runs
  end

  private

  def create_source_runs
    create_table :source_runs, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :source_key, null: false
      t.string :transport, null: false
      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.bigint :fetched_count
      t.bigint :discovered_count
      t.bigint :observed_count
      t.string :run_key
      t.string :collector_version
      t.string :adapter_version
      t.string :parser_version
      t.string :idempotency_key, null: false
      t.string :error_class
      t.text :error_message
      t.jsonb :error_details, null: false, default: {}
      t.jsonb :provenance, null: false, default: {}
      t.timestamps
    end

    add_index :source_runs, :idempotency_key, unique: true
    add_index :source_runs, %i[source_key started_at]
    add_index :source_runs, %i[source_key status finished_at], name: "index_source_runs_on_source_status_finished"
  end

  def create_raw_payloads
    create_table :raw_payloads, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :source_run, null: false, type: :uuid, foreign_key: true
      t.text :source_uri
      t.string :content_digest, null: false
      t.string :content_type
      t.string :encoding
      t.binary :body, null: false
      t.bigint :byte_size, null: false
      t.datetime :captured_at, null: false
      t.string :idempotency_key, null: false
      t.jsonb :provenance, null: false, default: {}
      t.timestamps
    end

    add_index :raw_payloads, :idempotency_key, unique: true
    add_index :raw_payloads, %i[source_run_id content_digest]
    add_index :raw_payloads, %i[source_run_id captured_at]
  end

  def create_ingestion_records
    create_table :ingestion_records, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :source_run, null: false, type: :uuid, foreign_key: true
      t.references :raw_payload, null: false, type: :uuid, foreign_key: true
      t.string :transport, null: false
      t.string :ingress_interface
      t.datetime :ingested_at, null: false
      t.string :collector_version
      t.string :adapter_version
      t.string :parser_version
      t.string :idempotency_key, null: false
      t.jsonb :provenance, null: false, default: {}
      t.timestamps
    end

    add_index :ingestion_records, :idempotency_key, unique: true
    add_index :ingestion_records, %i[source_run_id ingested_at]
  end

  def extend_source_observations
    add_reference :source_observations, :source_run, type: :uuid, foreign_key: true, index: false
    add_reference :source_observations, :ingestion_record, type: :uuid, foreign_key: true, index: false
    add_column :source_observations, :original_url, :text
    add_column :source_observations, :source_published_at, :datetime
    add_column :source_observations, :source_updated_at, :datetime
    add_column :source_observations, :ingested_at, :datetime
    add_column :source_observations, :presence_state, :string, null: false, default: "present"
    add_column :source_observations, :parser_version, :string
  end

  def backfill_existing_source_observations
    source_observation_class.find_each do |observation|
      metadata = observation.metadata || {}
      parser_version = metadata["parser_version"].presence
      recorded_at = observation.created_at || observation.observed_at
      finished_at = [ recorded_at, observation.observed_at ].compact.max
      provenance = { "backfilled_source_observation_id" => observation.id.to_s }

      source_run = source_run_class.create!(
        source_key: observation.source_key,
        transport: observation.transport,
        status: "succeeded",
        started_at: observation.observed_at,
        finished_at:,
        observed_count: 1,
        collector_version: metadata["collector"],
        adapter_version: metadata["adapter_version"],
        parser_version:,
        idempotency_key: observation.idempotency_key,
        provenance:,
        created_at: recorded_at,
        updated_at: observation.updated_at || recorded_at
      )

      raw_body = JSON.generate(canonicalize(observation.payload || {})).b
      raw_digest = Digest::SHA256.hexdigest(raw_body)
      unless raw_digest == observation.content_digest
        raise "cannot backfill SourceObservation #{observation.id}: reconstructed raw payload digest differs"
      end

      raw_payload = raw_payload_class.create!(
        source_run_id: source_run.id,
        source_uri: observation.canonical_url,
        content_digest: raw_digest,
        content_type: "application/json",
        encoding: "UTF-8",
        body: raw_body,
        byte_size: raw_body.bytesize,
        captured_at: observation.observed_at,
        idempotency_key: observation.idempotency_key,
        provenance:,
        created_at: recorded_at,
        updated_at: observation.updated_at || recorded_at
      )

      ingestion_record = ingestion_record_class.create!(
        source_run_id: source_run.id,
        raw_payload_id: raw_payload.id,
        transport: observation.transport,
        ingested_at: recorded_at,
        collector_version: metadata["collector"],
        adapter_version: metadata["adapter_version"],
        parser_version:,
        idempotency_key: observation.idempotency_key,
        provenance:,
        created_at: recorded_at,
        updated_at: observation.updated_at || recorded_at
      )

      observation.update_columns(
        source_run_id: source_run.id,
        ingestion_record_id: ingestion_record.id,
        ingested_at: recorded_at,
        parser_version:
      )
    end
  end

  def enforce_source_observation_links
    change_column_null :source_observations, :source_run_id, false
    change_column_null :source_observations, :ingestion_record_id, false
    change_column_null :source_observations, :ingested_at, false

    add_index :source_observations, %i[source_run_id observed_at]
    add_index :source_observations, :ingestion_record_id
  end

  def source_observation_class
    @source_observation_class ||= Class.new(ActiveRecord::Base) do
      self.table_name = "source_observations"
    end
  end

  def source_run_class
    @source_run_class ||= Class.new(ActiveRecord::Base) do
      self.table_name = "source_runs"
    end
  end

  def raw_payload_class
    @raw_payload_class ||= Class.new(ActiveRecord::Base) do
      self.table_name = "raw_payloads"
    end
  end

  def ingestion_record_class
    @ingestion_record_class ||= Class.new(ActiveRecord::Base) do
      self.table_name = "ingestion_records"
    end
  end

  def canonicalize(value)
    case value
    when Hash
      value.to_h.transform_keys(&:to_s).sort.to_h.transform_values { canonicalize(_1) }
    when Array
      value.map { canonicalize(_1) }
    else
      value
    end
  end
end
