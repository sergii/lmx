# frozen_string_literal: true

require "rails_helper"

RSpec.describe "openings.submit MCP vertical slice", type: :model do
  let(:workspace_uuid) { SecureRandom.uuid }
  let(:workspace_id) { TypeID.from_uuid("org", workspace_uuid).to_s }
  let(:credential) { "credential:opening-submit" }
  let(:capabilities) { %w[submit:openings read:openings] }
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
  let(:arguments) do
    {
      title: "Senior Ruby Engineer",
      company_name: "Example Labs",
      url: "https://jobs.dou.ua/companies/example/vacancies/4242/#apply",
      location: "Kyiv / Remote",
      remote_policy: "Remote within Europe",
      compensation: "$6,000-$7,000",
      notes: "Submitted by an agent after user review"
    }
  end

  before do
    connection = ActiveRecord::Base.connection
    connection.execute(<<~SQL)
      INSERT INTO organizations (id, name, slug, created_at, updated_at)
      VALUES (
        #{connection.quote(workspace_uuid)},
        'Opening submit vertical',
        #{connection.quote("opening-submit-#{SecureRandom.hex(4)}")},
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
    SQL
  end

  it "publishes a provenance-free MCP input schema for URL-backed and no-URL submissions" do
    tool = Integration::Mcp::CommandTools.all.find { _1.fetch(:name) == "openings.submit" }

    expect(tool).not_to be_nil
    schema = tool.fetch(:inputSchema)
    expect(schema.fetch("required")).to eq([ "title" ])
    expect(schema.fetch("properties").keys).to contain_exactly(
      "title", "company_name", "url", "location", "remote_policy", "compensation", "notes"
    )
    expect(schema.fetch("properties")).not_to have_key("principal")
    expect(schema.fetch("additionalProperties")).to be(false)
    expect(Integration::Command::Contracts.fetch("openings.submit").required_capability).to eq("submit:openings")
  end

  it "runs MCP -> authorization -> Inbox -> Market Catalog -> Event/Outbox and replays safely" do
    adapter = Integration::CommandStack.build(credential_source:)
    context = command_context("url-1")

    first = adapter.call(name: "openings.submit", arguments:, context:)
    replay = adapter.call(name: "openings.submit", arguments:, context:)

    expect(first.fetch(:isError)).to be(false)
    expect(replay.fetch(:isError)).to be(false)
    first_payload = first.fetch(:structuredContent)
    replay_payload = replay.fetch(:structuredContent)
    opening = first_payload.fetch(:data).fetch("opening")
    posting = first_payload.fetch(:data).fetch("posting")

    expect(first_payload.dig(:meta, :command, :replayed)).to be(false)
    expect(replay_payload.dig(:meta, :command, :replayed)).to be(true)
    expect(replay_payload.fetch(:data)).to eq(first_payload.fetch(:data))
    expect(first_payload.fetch(:data).fetch("created")).to be(true)
    expect(opening.dig("metadata", "ingress_interface")).to eq("mcp")
    expect(posting).to include(
      "source_key" => "dou",
      "canonical_url" => "https://jobs.dou.ua/companies/example/vacancies/4242/"
    )
    expect(posting.dig("metadata", "ingress_interface")).to eq("mcp")

    Workspace::Api.with_workspace(workspace_id:) do
      command = Platform::Reliability::Api.fetch_command(command_id: context.command_id)
      expect(command.fetch(:status)).to eq("succeeded")
      expect(command.fetch(:attempt_count)).to eq(1)
      expect(reliability_count("platform_inbox_messages", "command_id", context.command_id)).to eq(1)
      expect(reliability_count("platform_domain_events", "command_id", context.command_id)).to eq(1)
      expect(reliability_count("platform_outbox_messages", "message_type", "job_opening.created")).to eq(1)

      event = Platform::DomainEvent.find_by!(command_id: context.command_id)
      expect(event.event_type).to eq("job_opening.created")
      expect(event.interface).to eq("mcp")
      expect(event.data).to include(
        "job_opening_id" => opening.fetch("id"),
        "job_posting_id" => posting.fetch("id"),
        "ingress_interface" => "mcp",
        "notes" => "Submitted by an agent after user review"
      )
    end
  end

  it "reuses canonical URL identity across distinct MCP commands without inventing manual provenance" do
    adapter = Integration::CommandStack.build(credential_source:)
    first = adapter.call(name: "openings.submit", arguments:, context: command_context("url-a"))
    second_context = command_context("url-b")
    second = adapter.call(name: "openings.submit", arguments:, context: second_context)

    expect(first.fetch(:isError)).to be(false)
    expect(second.fetch(:isError)).to be(false)
    expect(second.dig(:structuredContent, :data, "created")).to be(false)
    expect(second.dig(:structuredContent, :data, "opening", "id")).to eq(
      first.dig(:structuredContent, :data, "opening", "id")
    )
    expect(second.dig(:structuredContent, :data, "posting", "id")).to eq(
      first.dig(:structuredContent, :data, "posting", "id")
    )

    Workspace::Api.with_workspace(workspace_id:) do
      event = Platform::DomainEvent.find_by!(command_id: second_context.command_id)
      expect(event.event_type).to eq("job_opening.submission_recorded")
      expect(event.data.fetch("ingress_interface")).to eq("mcp")
      expect(Platform::DomainEvent.where(event_type: "job_opening.manual_submission_recorded")).to be_empty
    end
  end

  it "supports a private no-URL opening through the same command path" do
    adapter = Integration::CommandStack.build(credential_source:)
    response = adapter.call(
      name: "openings.submit",
      arguments: {
        title: "Principal Rails Engineer",
        company_name: "Private Search Co",
        location: "Europe",
        notes: "Recruiter message without a public vacancy URL"
      },
      context: command_context("no-url")
    )

    expect(response.fetch(:isError)).to be(false)
    expect(response.dig(:structuredContent, :data, "created")).to be(true)
    expect(response.dig(:structuredContent, :data, "posting")).to be_nil
    expect(response.dig(:structuredContent, :data, "opening", "metadata")).to include(
      "ingress_interface" => "mcp",
      "company_name" => "Private Search Co",
      "location_wording" => "Europe"
    )
  end

  it "fails authorization before creating an Inbox record or canonical opening" do
    limited_source = Object.new
    limited_source.define_singleton_method(:resolve) do |context|
      {
        workspace_id: context.workspace_id,
        principal: context.principal,
        credential: context.credential,
        capabilities: [ "read:openings" ]
      }
    end
    adapter = Integration::CommandStack.build(credential_source: limited_source)
    context = command_context("denied")

    response = adapter.call(name: "openings.submit", arguments:, context:)

    expect(response.fetch(:isError)).to be(true)
    expect(response.dig(:structuredContent, :error, :code)).to eq("unauthorized")
    Workspace::Api.with_workspace(workspace_id:) do
      expect do
        Platform::Reliability::Api.fetch_command(command_id: context.command_id)
      end.to raise_error(Platform::Reliability::Api::NotFound)
      expect(MarketCatalog::Api.search_openings.fetch(:items)).to be_empty
    end
  end

  it "rejects conflicting reuse of the same command identity without a second opening" do
    adapter = Integration::CommandStack.build(credential_source:)
    context = command_context("conflict")
    first = adapter.call(name: "openings.submit", arguments:, context:)
    conflicting = adapter.call(
      name: "openings.submit",
      arguments: arguments.merge(title: "Different opening"),
      context:
    )

    expect(first.fetch(:isError)).to be(false)
    expect(conflicting.fetch(:isError)).to be(true)
    expect(conflicting.dig(:structuredContent, :error, :code)).to eq("idempotency_conflict")

    Workspace::Api.with_workspace(workspace_id:) do
      expect(MarketCatalog::Api.search_openings.fetch(:items).size).to eq(1)
    end
  end

  private

  def command_context(key)
    Integration::Command::Context.new(
      workspace_id:,
      principal: "user:serhii",
      credential:,
      actor: "human:serhii",
      executor: "agent:chatgpt",
      interface: "mcp",
      client: "chatgpt",
      request_id: "request-#{key}",
      correlation_id: "correlation-opening-submit",
      causation_id: "request-#{key}",
      message_id: "message-opening-submit-#{key}",
      command_id: "command-opening-submit-#{key}",
      idempotency_key: "idem-opening-submit-#{key}"
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
