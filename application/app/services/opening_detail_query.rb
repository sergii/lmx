# frozen_string_literal: true

require "time"

class OpeningDetailQuery
  FACT_KEYS = {
    compensation: %w[compensation_original_text compensation_text salary_text compensation salary],
    location: %w[location_wording location_text location],
    remote_policy: %w[remote_policy_wording remote_policy remote_work remote]
  }.freeze

  class << self
    def call(**attributes)
      new(**attributes).call
    end
  end

  def initialize(workspace_id:, user_id:, opening_id:, market_api: MarketCatalog::Api,
    talent_api: TalentProfile::Api, intelligence_api: Intelligence::Api,
    personal_api: PersonalCrm::Api)
    @workspace_id = workspace_id
    @user_id = user_id
    @opening_id = opening_id
    @market_api = market_api
    @talent_api = talent_api
    @intelligence_api = intelligence_api
    @personal_api = personal_api
    @companies = {}
  end

  def call
    opening = market_api.fetch_opening(opening_id:)
    posting_contexts = posting_contexts(opening)
    candidate = linked_candidate
    assessment = latest_assessment(opening, candidate:)
    personal_context = personal_context(opening, candidate:)

    {
      opening: opening_props(opening, posting_contexts:),
      company: company_props(opening[:primary_company_id]),
      parties: party_props(opening.fetch(:parties)),
      postings: posting_contexts.map { posting_props(_1) },
      candidate: candidate_props(candidate),
      assessment: assessment_props(assessment, candidate:, opening:),
      personal_crm: personal_crm_props(personal_context)
    }
  end

  private

  attr_reader :workspace_id, :user_id, :opening_id, :market_api, :talent_api,
    :intelligence_api, :personal_api, :companies

  def opening_props(opening, posting_contexts:)
    documents = fact_documents(opening, posting_contexts)

    {
      id: opening.fetch(:id),
      title: opening.fetch(:canonical_title),
      lifecycle_state: opening.fetch(:lifecycle_state),
      first_seen_at: iso8601(opening[:first_seen_at]),
      last_seen_at: iso8601(opening[:last_seen_at]),
      closed_at: iso8601(opening[:closed_at]),
      location: fact_text(documents, FACT_KEYS.fetch(:location)),
      remote_policy: fact_text(documents, FACT_KEYS.fetch(:remote_policy)),
      compensation: fact_text(documents, FACT_KEYS.fetch(:compensation)),
      metadata: opening.fetch(:metadata),
      posting_count: posting_contexts.length,
      snapshot_count: posting_contexts.sum { _1.fetch(:history).length }
    }
  end

  def posting_contexts(opening)
    opening.fetch(:job_posting_ids).filter_map do |posting_id|
      posting = market_api.fetch_posting(posting_id:)
      history = market_api.fetch_posting_history(posting_id:)
      { posting:, history: }
    rescue MarketCatalog::Api::NotFound
      nil
    end
  end

  def posting_props(context)
    posting = context.fetch(:posting)
    history = context.fetch(:history)

    {
      id: posting.fetch(:id),
      source_key: posting.fetch(:source_key),
      title: posting.fetch(:title),
      lifecycle_state: posting.fetch(:lifecycle_state),
      external_id: posting[:external_id],
      canonical_url: posting[:canonical_url],
      application_url: posting[:application_url],
      publisher: company_props(posting[:publisher_company_id]),
      source_published_at: iso8601(posting[:source_published_at]),
      source_updated_at: iso8601(posting[:source_updated_at]),
      first_seen_at: iso8601(posting[:first_seen_at]),
      last_confirmed_present_at: iso8601(posting[:last_confirmed_present_at]),
      missing_since: iso8601(posting[:missing_since]),
      metadata: posting.fetch(:metadata),
      changed: materially_changed?(history),
      history: history.reverse.map { snapshot_props(_1) }
    }
  end

  def snapshot_props(snapshot)
    {
      id: snapshot.fetch(:id),
      source_observation_id: snapshot.fetch(:source_observation_id),
      observed_at: iso8601(snapshot[:observed_at]),
      presence_state: snapshot.fetch(:presence_state),
      title: snapshot[:title],
      source_published_at: iso8601(snapshot[:source_published_at]),
      source_updated_at: iso8601(snapshot[:source_updated_at]),
      facts: snapshot.fetch(:facts),
      content_digest: snapshot.fetch(:content_digest),
      normalizer_key: snapshot.fetch(:normalizer_key),
      normalizer_version: snapshot.fetch(:normalizer_version),
      metadata: snapshot.fetch(:metadata),
      created_at: iso8601(snapshot[:created_at])
    }
  end

  def party_props(parties)
    parties.map do |party|
      {
        id: party.fetch(:id),
        role: party.fetch(:role),
        label: party[:party_label],
        confidence: party.fetch(:confidence),
        company: company_props(party[:company_id]),
        evidence: party.fetch(:evidence),
        metadata: party.fetch(:metadata)
      }
    end
  end

  def company_props(company_id)
    return unless company_id

    company = companies[company_id] ||= market_api.fetch_company(company_id:)
    {
      id: company.fetch(:id),
      name: company.fetch(:canonical_name),
      website_url: company[:website_url],
      primary_domain: company[:primary_domain],
      metadata: company.fetch(:metadata)
    }
  rescue MarketCatalog::Api::NotFound
    nil
  end

  def linked_candidate
    talent_api.fetch_candidate_for_user(user_id:)
  rescue TalentProfile::Api::NotFound
    nil
  end

  def latest_assessment(opening, candidate:)
    return unless candidate

    intelligence_api.fetch_latest_match(
      workspace_id:,
      candidate_id: candidate.fetch(:id),
      job_opening_id: opening.fetch(:id)
    )
  rescue Intelligence::Api::NotFound
    nil
  end

  def personal_context(opening, candidate:)
    return unless candidate

    personal_api.fetch_opening_context(
      workspace_id:,
      candidate_id: candidate.fetch(:id),
      job_opening_id: opening.fetch(:id)
    )
  end

  def candidate_props(candidate)
    return unless candidate

    {
      id: candidate.fetch(:id),
      name: [ candidate[:first_name], candidate[:last_name] ].compact.join(" "),
      profile_version_id: candidate.dig(:profile_version, :id),
      profile_version_number: candidate.dig(:profile_version, :version_number)
    }
  end

  def personal_crm_props(context)
    return unless context

    disposition = context[:disposition]
    {
      disposition: disposition && {
        id: disposition.fetch(:id),
        state: disposition.fetch(:state),
        decided_at: iso8601(disposition[:decided_at])
      },
      applications: context.fetch(:applications).map do |application|
        {
          id: application.fetch(:id),
          via_posting_id: application[:via_posting_id],
          stage: application.fetch(:stage),
          started_at: iso8601(application[:started_at]),
          applied_at: iso8601(application[:applied_at]),
          channel: application[:channel],
          next_action: application[:next_action],
          next_action_at: iso8601(application[:next_action_at])
        }
      end
    }
  end

  def assessment_props(assessment, candidate:, opening:)
    return unless assessment

    profile_stale = candidate&.dig(:profile_version, :id).present? &&
      candidate.dig(:profile_version, :id) != assessment.fetch(:candidate_profile_version_id)
    opening_stale = opening[:last_seen_at].present? && assessment[:opening_evidence_cutoff].present? &&
      opening.fetch(:last_seen_at) > assessment.fetch(:opening_evidence_cutoff)

    {
      id: assessment.fetch(:id),
      version_number: assessment.fetch(:version_number),
      opportunity_score: assessment[:opportunity_score],
      action_priority: assessment[:action_priority],
      score_details: assessment.fetch(:score_details),
      strengths: assessment.fetch(:strengths),
      gaps: assessment.fetch(:gaps),
      risks: assessment.fetch(:risks),
      recommendation: assessment[:recommendation],
      interview_angles: assessment.fetch(:interview_angles),
      evidence_references: assessment.fetch(:evidence_references),
      scoring_policy_version: assessment.fetch(:scoring_policy_version),
      processor: assessment.fetch(:processor),
      candidate_profile_version_id: assessment.fetch(:candidate_profile_version_id),
      opening_evidence_cutoff: iso8601(assessment[:opening_evidence_cutoff]),
      opening_snapshot: assessment.fetch(:opening_snapshot),
      generated_at: iso8601(assessment[:generated_at]),
      created_at: iso8601(assessment[:created_at]),
      stale: profile_stale || opening_stale,
      stale_reasons: [
        ("candidate profile changed" if profile_stale),
        ("opening evidence changed" if opening_stale)
      ].compact
    }
  end

  def materially_changed?(history)
    history.filter_map { _1[:content_digest] }.uniq.many?
  end

  def fact_documents(opening, posting_contexts)
    documents = [ opening[:metadata] ]

    posting_contexts.each do |context|
      documents << context.dig(:posting, :metadata)
      documents << context.fetch(:history).last&.fetch(:facts, nil)
    end

    documents.compact
  end

  def fact_text(documents, keys)
    documents.reverse_each do |document|
      value = find_fact(document, keys)
      formatted = format_fact(value)
      return formatted if formatted.present?
    end

    nil
  end

  def find_fact(value, keys)
    return unless value.is_a?(Hash)

    keys.each do |key|
      return value[key] if value.key?(key)
      return value[key.to_sym] if value.key?(key.to_sym)
    end

    value.each_value do |nested|
      found = find_fact(nested, keys)
      return found unless found.nil?
    end

    nil
  end

  def format_fact(value)
    case value
    when String
      value.strip.presence
    when Numeric
      value.to_s
    when TrueClass
      "Remote"
    when FalseClass
      "On-site"
    when Array
      value.filter_map { format_fact(_1) }.join(", ").presence
    when Hash
      format_fact_hash(value)
    end
  end

  def format_fact_hash(value)
    direct_value = value[:value] || value["value"] || value[:text] || value["text"] ||
      value[:original_text] || value["original_text"] || value[:label] || value["label"]
    return format_fact(direct_value) unless direct_value.nil?

    minimum = value[:min] || value["min"] || value[:minimum] || value["minimum"]
    maximum = value[:max] || value["max"] || value[:maximum] || value["maximum"]
    currency = value[:currency] || value["currency"]
    return unless minimum || maximum || currency

    range = [ minimum, maximum ].compact.join("-")
    [ range.presence, currency ].compact.join(" ").presence
  end

  def iso8601(value)
    return if value.nil?
    return value.iso8601 if value.respond_to?(:iso8601)

    Time.iso8601(value.to_s).iso8601
  end
end
