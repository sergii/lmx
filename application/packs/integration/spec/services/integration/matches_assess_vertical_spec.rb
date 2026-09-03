# frozen_string_literal: true

require "rails_helper"

RSpec.describe "matches.assess MCP vertical slice", type: :model do
  let(:workspace_uuid) { SecureRandom.uuid }
  let(:workspace_id) { TypeID.from_uuid("org", workspace_uuid).to_s }
  let(:candidate_id) { TypeID.from_uuid("candidate", SecureRandom.uuid).to_s }
  let(:profile_version_id) { TypeID.from_uuid("candidate_profile_version", SecureRandom.uuid).to_s }
  let(:opening_id) { TypeID.from_uuid("opening", SecureRandom.uuid).to_s }
  let(:profile_digest) { "d" * 64 }
  let(:command_id) { "command-#{SecureRandom.uuid}" }
  let(:idempotency_key) { "idem-#{SecureRandom.uuid}" }
  let(:message_id) { "message-#{SecureRandom.uuid}" }
  let(:credential) { "credential:vertical" }
  let(:capabilities) { %w[assess:matches read:matches] }
  let(:credential_source) do
    source_capabilities = capabilities
    Object.new.tap do |source|
      source.define_singleton_method(:resolve) do |context|
        {
          workspace_id: context.workspace_id,
          principal: context.principal,
          credential: context.credential,
          capabilities: source_capabilities
        }
      end
    end
  end
  let(:profile_snapshot) do
    {
      id: profile_version_id,
      candidate_id:,
      version_number: 4,
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
      last_seen_at: Time.zone.parse("2026-09-02 18:00:00"),
      metadata: { "remote" => true }.freeze,
      parties: [].freeze,
      job_posting_ids: [].freeze
    }.freeze
  end
  let(:arguments) do
    {
      candidate_id:,
      candidate_profile_version_id: profile_version_id,
      job_opening_id: opening_id,
      opening_evidence_cutoff: "2026-09-02T18:00:00Z",
      scoring_policy_version: "default:v1",
      opportunity_score: 88.5,
      action_priority: 94.0,
      score_details: { technical_fit: 0.96 },
      strengths: [ "deep Rails experience" ],
      gaps: [ "domain-specific context" ],
      risks: [],
      recommendation: "Apply now",
      interview_angles: [ "production ownership" ],
      evidence_references: [ profile_version_id ],
      processor_kind: "agent",
      processor_key: "chatgpt",
      processor_version: "gpt-5.6-sol",
      model_name: "gpt-5.6-sol",
      model_version: "2026-09-02",
      generated_at: "2026-09-02T18:05:00Z"
    }
  end

  before do
    connection = ActiveRecord::Base.connection
    connection.execute(<<~SQL)
      INSERT INTO organizations (id, name, slug, created_at, updated_at)
      VALUES (
        #{connection.quote(workspace_uuid)},
        'Match vertical',
        #{connection.quote("match-vertical-#{SecureRandom.hex(4)}")},
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
    SQL
    allow(TalentProfile::Api).to receive(:fetch_profile_version).and_return(profile_snapshot)
    allow(MarketCatalog::Api).to receive(:fetch_opening).and_return(opening_snapshot)
  end

  it "runs MCP -> authorization -> Inbox -> Intelligence -> Event/Outbox and replays safely" do
    command_adapter = Integration::CommandStack.build(credential_source:)
    context = command_context

    first = command_adapter.call(name: "matches.assess", arguments:, context:)
    replay = command_adapter.call(name: "matches.assess", arguments:, context:)

    expect(first.fetch(:isError)).to be(false)
    expect(replay.fetch(:isError)).to be(false)
    first_payload = first.fetch(:structuredContent)
    replay_payload = replay.fetch(:structuredContent)
    assessment_id = first_payload.fetch(:data).fetch("id")

    expect(first_payload.dig(:meta, :command, :replayed)).to be(false)
    expect(replay_payload.dig(:meta, :command, :replayed)).to be(true)
    expect(replay_payload.fetch(:data)).to eq(first_payload.fetch(:data))
    expect(first_payload.fetch(:data)).to include(
      "candidate_id" => candidate_id,
      "candidate_profile_version_id" => profile_version_id,
      "job_opening_id" => opening_id,
      "version_number" => 1,
      "recommendation" => "Apply now"
    )

    Workspace::Api.with_workspace(workspace_id:) do
      command = Platform::Reliability::Api.fetch_command(command_id:)
      expect(command.fetch(:status)).to eq("succeeded")
      expect(command.fetch(:attempt_count)).to eq(1)
      expect(reliability_count("platform_domain_events", "command_id", command_id)).to eq(1)
      expect(
        reliability_count("platform_outbox_messages", "message_type", Intelligence::Api::MATCH_ASSESSMENT_RECORDED)
      ).to eq(1)
    end

    read_adapter = Integration::ReadStack.build(credential_source:)
    read = read_adapter.call(
      name: "matches.get",
      arguments: { id: assessment_id },
      context: read_context
    )

    expect(read.fetch(:isError)).to be(false)
    expect(read.dig(:structuredContent, :data, :id)).to eq(assessment_id)
    expect(read.dig(:structuredContent, :data, :recommendation)).to eq("Apply now")
  end

  it "fails authorization before creating an Inbox record" do
    limited_source = Object.new
    limited_source.define_singleton_method(:resolve) do |context|
      {
        workspace_id: context.workspace_id,
        principal: context.principal,
        credential: context.credential,
        capabilities: [ "read:matches" ]
      }
    end
    adapter = Integration::CommandStack.build(credential_source: limited_source)

    response = adapter.call(name: "matches.assess", arguments:, context: command_context)

    expect(response.fetch(:isError)).to be(true)
    expect(response.dig(:structuredContent, :error, :code)).to eq("unauthorized")
    Workspace::Api.with_workspace(workspace_id:) do
      expect do
        Platform::Reliability::Api.fetch_command(command_id:)
      end.to raise_error(Platform::Reliability::Api::NotFound)
    end
  end

  it "rejects conflicting reuse of the same idempotency identity without a second assessment" do
    adapter = Integration::CommandStack.build(credential_source:)
    context = command_context
    first = adapter.call(name: "matches.assess", arguments:, context:)
    conflicting = adapter.call(
      name: "matches.assess",
      arguments: arguments.merge(recommendation: "Do not apply"),
      context:
    )

    expect(first.fetch(:isError)).to be(false)
    expect(conflicting.fetch(:isError)).to be(true)
    expect(conflicting.dig(:structuredContent, :error, :code)).to eq("idempotency_conflict")

    Workspace::Api.with_workspace(workspace_id:) do
      connection = ActiveRecord::Base.connection
      count = connection.select_value(
        "SELECT COUNT(*) FROM intelligence_match_assessments WHERE candidate_id = " \
          "#{connection.quote(candidate_id)} AND job_opening_id = #{connection.quote(opening_id)}"
      ).to_i
      expect(count).to eq(1)
    end
  end

  private

  def command_context
    Integration::Command::Context.new(
      workspace_id:,
      principal: "user:serhii",
      credential:,
      actor: "human:serhii",
      executor: "agent:chatgpt",
      interface: "mcp",
      client: "chatgpt",
      request_id: "request-#{command_id}",
      correlation_id: "correlation-vertical",
      causation_id: "request-#{command_id}",
      message_id:,
      command_id:,
      idempotency_key:
    )
  end

  def read_context
    Integration::Read::Context.new(
      workspace_id:,
      principal: "user:serhii",
      credential:,
      actor: "human:serhii",
      executor: "agent:chatgpt",
      interface: "mcp",
      client: "chatgpt",
      request_id: "read-#{command_id}",
      correlation_id: "correlation-vertical"
    )
  end

  def reliability_count(table, column, value)
    connection = ActiveRecord::Base.connection
    connection.select_value(
      "SELECT COUNT(*) FROM #{connection.quote_table_name(table)} " \
        "WHERE #{connection.quote_column_name(column)} = #{connection.quote(value)}"
    ).to_i
  end
end
