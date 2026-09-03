# frozen_string_literal: true

require "time"

class ApplicationsWorkflowQuery
  class << self
    def call(**attributes)
      new(**attributes).call
    end
  end

  def initialize(workspace_id:, user_id:, view: nil, personal_api: PersonalCrm::Api,
    talent_api: TalentProfile::Api, market_api: MarketCatalog::Api)
    @workspace_id = workspace_id
    @user_id = user_id
    @view = normalized_view(view)
    @personal_api = personal_api
    @talent_api = talent_api
    @market_api = market_api
    @openings = {}
    @companies = {}
  end

  def call
    candidate = linked_candidate
    applications = candidate ? personal_api.search_applications(
      workspace_id:,
      candidate_id: candidate.fetch(:id)
    ) : []

    {
      stages: personal_api.application_stages,
      initial_view: view,
      candidate: candidate_props(candidate),
      applications: applications.map { application_props(_1) }
    }
  end

  private

  attr_reader :workspace_id, :user_id, :view, :personal_api, :talent_api, :market_api,
    :openings, :companies

  def linked_candidate
    talent_api.fetch_candidate_for_user(user_id:)
  rescue TalentProfile::Api::NotFound
    nil
  end

  def candidate_props(candidate)
    return unless candidate

    {
      id: candidate.fetch(:id),
      name: [ candidate[:first_name], candidate[:last_name] ].compact.join(" ")
    }
  end

  def application_props(application)
    opening = opening(application.fetch(:job_opening_id))
    company = company(opening[:primary_company_id]) if opening

    {
      id: application.fetch(:id),
      stage: application.fetch(:stage),
      started_at: iso8601(application[:started_at]),
      applied_at: iso8601(application[:applied_at]),
      channel: application[:channel],
      next_action: application[:next_action],
      next_action_at: iso8601(application[:next_action_at]),
      job_opening_id: application.fetch(:job_opening_id),
      via_posting_id: application[:via_posting_id],
      opening: opening && {
        id: opening.fetch(:id),
        title: opening.fetch(:canonical_title),
        lifecycle_state: opening.fetch(:lifecycle_state),
        company: company && {
          id: company.fetch(:id),
          name: company.fetch(:canonical_name)
        }
      }
    }
  end

  def opening(opening_id)
    return openings[opening_id] if openings.key?(opening_id)

    openings[opening_id] = market_api.fetch_opening(opening_id:)
  rescue MarketCatalog::Api::NotFound
    openings[opening_id] = nil
  end

  def company(company_id)
    return unless company_id
    return companies[company_id] if companies.key?(company_id)

    companies[company_id] = market_api.fetch_company(company_id:)
  rescue MarketCatalog::Api::NotFound
    companies[company_id] = nil
  end

  def normalized_view(value)
    value = value.to_s
    %w[kanban list table].include?(value) ? value : "kanban"
  end

  def iso8601(value)
    return if value.nil?
    return value.iso8601 if value.respond_to?(:iso8601)

    Time.iso8601(value.to_s).iso8601
  end
end
