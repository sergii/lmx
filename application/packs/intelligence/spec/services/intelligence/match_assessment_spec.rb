# frozen_string_literal: true

require "rails_helper"
require "pg"

RSpec.describe "Intelligence MatchAssessment core", type: :model do
  INTELLIGENCE_RLS_RUNTIME_ROLE = ENV.fetch("POSTGRES_RLS_TEST_USER", "lmx_rls_test")
  INTELLIGENCE_RLS_RUNTIME_PASSWORD = ENV.fetch("POSTGRES_RLS_TEST_PASSWORD", "lmx_rls_test")

  let(:connection) { ActiveRecord::Base.connection }
  let(:workspace_uuid) { SecureRandom.uuid }
  let(:workspace_id) { TypeID.from_uuid("org", workspace_uuid).to_s }
  let(:candidate_id) { TypeID.from_uuid("candidate", SecureRandom.uuid).to_s }
  let(:profile_version_id) { TypeID.from_uuid("candidate_profile_version", SecureRandom.uuid).to_s }
  let(:opening_id) { TypeID.from_uuid("opening", SecureRandom.uuid).to_s }
  let(:profile_digest) { "a" * 64 }
  let(:observed_at) { Time.zone.parse("2026-09-02 18:30:00") }
  let(:generated_at) { observed_at + 5.minutes }
  let(:profile_snapshot) do
    {
      id: profile_version_id,
      candidate_id:,
      version_number: 3,
      schema_version: 1,
      profile: { "skills" => [ "Ruby", "Rails" ] }.freeze,
      content_digest: profile_digest,
      evidence_ids: [].freeze
    }.freeze
  end
  let(:opening_snapshot) do
    {
      id: opening_id,
      canonical_title: "Senior Ruby Engineer",
      lifecycle_state: "open",
      last_seen_at: observed_at,
      metadata: { "remote" => true }.freeze,
      parties: [].freeze,
      job_posting_ids: [].freeze
    }.freeze
  end
  let(:talent_api) { double("TalentProfileApi", fetch_profile_version: profile_snapshot) }
  let(:market_api) { double("MarketCatalogApi", fetch_opening: opening_snapshot) }

  before(:context) do
    provision_intelligence_runtime_role!
  end

  around do |example|
    previous = connection.select_value("SELECT current_setting('app.current_organization', true)")
    set_workspace(workspace_uuid)
    example.run
  ensure
    if previous.present?
      set_workspace(previous)
    else
      connection.execute("RESET app.current_organization")
    end
  end

  it "records immutable versioned assessments against exact profile and opening evidence" do
    first = record_assessment(
      opportunity_score: 81.25,
      action_priority: 92.5,
      strengths: [ "strong Rails depth" ],
      gaps: [ "domain ramp-up" ],
      risks: [ "compensation unknown" ],
      recommendation: "Apply now",
      interview_angles: [ "production ownership" ],
      evidence_references: [ profile_version_id ],
      score_details: { "technical_fit" => 0.95 },
      processor_kind: "agent",
      processor_key: "hermes",
      processor_version: "2026-09",
      model_name: "example-model",
      model_version: "v1"
    )
    second = record_assessment(recommendation: "Reassessed after new evidence")

    expect(first.version_number).to eq(1)
    expect(second.version_number).to eq(2)
    expect(first.candidate_id).to eq(candidate_id)
    expect(first.candidate_profile_version_id).to eq(profile_version_id)
    expect(first.candidate_profile_content_digest).to eq(profile_digest)
    expect(first.job_opening_id).to eq(opening_id)
    expect(first.opening_evidence_cutoff).to eq(observed_at)
    expect(first.opening_snapshot).to include("id" => opening_id, "canonical_title" => "Senior Ruby Engineer")
    expect(first.score_details).to eq("technical_fit" => 0.95)
    expect(first.generated_at).to eq(generated_at)
    expect { first.update!(recommendation: "mutated") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "serializes a frozen public snapshot and returns the latest version" do
    allow(TalentProfile::Api).to receive(:fetch_profile_version).and_return(profile_snapshot)
    allow(MarketCatalog::Api).to receive(:fetch_opening).and_return(opening_snapshot)

    first = Intelligence::Api.record_match_assessment(**public_attributes, recommendation: "First")
    latest = Intelligence::Api.record_match_assessment(**public_attributes, recommendation: "Second")
    fetched = Intelligence::Api.fetch_latest_match(
      workspace_id:,
      candidate_id:,
      job_opening_id: opening_id
    )

    expect(first.fetch(:version_number)).to eq(1)
    expect(latest.fetch(:version_number)).to eq(2)
    expect(fetched).to eq(latest)
    expect(fetched).to be_frozen
    expect(fetched.fetch(:opening_snapshot)).to be_frozen
    expect(fetched.fetch(:processor)).to be_frozen
    expect(fetched.fetch(:candidate_profile_content_digest)).to eq(profile_digest)
  end

  it "maps missing cross-context inputs to the Intelligence public NotFound error" do
    allow(TalentProfile::Api).to receive(:fetch_profile_version).and_raise(TalentProfile::Api::NotFound)

    expect do
      Intelligence::Api.record_match_assessment(**public_attributes)
    end.to raise_error(Intelligence::Api::NotFound, "assessment input not found")
  end

  it "keeps another workspace from reading the assessment through PostgreSQL RLS" do
    assessment_uuid = SecureRandom.uuid
    other_workspace_uuid = SecureRandom.uuid
    other_workspace_id = TypeID.from_uuid("org", other_workspace_uuid).to_s
    owner_connection = PG.connect(**connection_options)
    runtime_connection = PG.connect(
      **connection_options.merge(
        user: INTELLIGENCE_RLS_RUNTIME_ROLE,
        password: INTELLIGENCE_RLS_RUNTIME_PASSWORD
      )
    )
    insert_committed_assessment(owner_connection, id: assessment_uuid, organization_id: workspace_uuid)

    runtime_connection.exec_params(
      "SELECT set_config('app.current_organization', $1, false)",
      [ workspace_uuid ]
    )
    expect(runtime_assessment_ids(runtime_connection)).to include(assessment_uuid)

    runtime_connection.exec_params(
      "SELECT set_config('app.current_organization', $1, false)",
      [ other_workspace_uuid ]
    )
    expect(runtime_assessment_ids(runtime_connection)).not_to include(assessment_uuid)

    expect do
      Intelligence::Api.fetch_match_assessment(
        workspace_id: other_workspace_id,
        assessment_id: TypeID.from_uuid("match_assessment", assessment_uuid).to_s
      )
    end.to raise_error(Intelligence::Api::NotFound)
  ensure
    runtime_connection&.close
    owner_connection&.exec_params("DELETE FROM intelligence_match_assessments WHERE id = $1", [ assessment_uuid ])
    owner_connection&.close
  end

  private

  def record_assessment(**overrides)
    Intelligence::RecordMatchAssessment.call(
      **public_attributes,
      talent_api:,
      market_api:,
      **overrides
    )
  end

  def public_attributes
    {
      workspace_id:,
      candidate_id:,
      candidate_profile_version_id: profile_version_id,
      job_opening_id: opening_id,
      opening_evidence_cutoff: observed_at,
      scoring_policy_version: "default:v1",
      generated_at:
    }
  end

  def set_workspace(uuid)
    connection.select_value(
      "SELECT set_config('app.current_organization', #{connection.quote(uuid.to_s)}, false)"
    )
  end

  def provision_intelligence_runtime_role!
    owner = ActiveRecord::Base.connection
    role = owner.quote_column_name(INTELLIGENCE_RLS_RUNTIME_ROLE)
    password = owner.quote(INTELLIGENCE_RLS_RUNTIME_PASSWORD)
    database = owner.quote_column_name(connection_options.fetch(:dbname))

    owner.execute(<<~SQL)
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = #{owner.quote(INTELLIGENCE_RLS_RUNTIME_ROLE)}) THEN
          CREATE ROLE #{role} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
        END IF;
      END
      $$;
    SQL
    owner.execute(
      "ALTER ROLE #{role} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD #{password}"
    )
    owner.execute("GRANT CONNECT ON DATABASE #{database} TO #{role}")
    owner.execute("GRANT USAGE ON SCHEMA public TO #{role}")
    owner.execute("GRANT SELECT ON intelligence_match_assessments TO #{role}")
  end

  def connection_options
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    {
      host: config.fetch(:host),
      port: config.fetch(:port),
      dbname: config.fetch(:database),
      user: config.fetch(:username),
      password: config.fetch(:password)
    }
  end

  def insert_committed_assessment(owner_connection, id:, organization_id:)
    params = [
      id,
      organization_id,
      candidate_id,
      profile_version_id,
      profile_digest,
      opening_id,
      observed_at
    ]

    owner_connection.exec_params(<<~SQL, params)
      INSERT INTO intelligence_match_assessments
        (id, organization_id, candidate_id, candidate_profile_version_id,
         candidate_profile_content_digest, job_opening_id, opening_evidence_cutoff,
         opening_snapshot, version_number, score_details, strengths, gaps, risks,
         interview_angles, evidence_references, scoring_policy_version, generated_at, created_at)
      VALUES
        ($1, $2, $3, $4, $5, $6, $7, '{}'::jsonb, 1, '{}'::jsonb, '[]'::jsonb,
         '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 'default:v1',
         CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def runtime_assessment_ids(runtime_connection)
    runtime_connection.exec("SELECT id FROM intelligence_match_assessments ORDER BY id").map { _1.fetch("id") }
  end
end
