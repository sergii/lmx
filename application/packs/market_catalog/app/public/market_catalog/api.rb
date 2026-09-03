# frozen_string_literal: true

module MarketCatalog
  module Api
    class Error < StandardError; end
    class NotFound < Error; end

    module_function

    def create_company(**attributes)
      company_snapshot(CreateCompany.call(**attributes))
    end

    def create_opening(**attributes)
      opening_snapshot(CreateOpening.call(**attributes))
    end

    def search_openings(query: nil, filters: {}, cursor: nil, limit: nil)
      result = SearchOpenings.call(query:, filters:, cursor:, limit:)

      {
        items: result.records.map { opening_snapshot(_1) }.freeze,
        next_cursor: result.next_cursor
      }.compact.freeze
    end

    def record_posting(**attributes)
      job_posting_snapshot(RecordPosting.call(**attributes))
    end

    def record_posting_snapshot(**attributes)
      posting_snapshot(RecordPostingSnapshot.call(**attributes))
    end

    def reconcile_posting_lifecycle(posting_id:)
      job_posting_snapshot(ReconcilePostingLifecycle.call(posting_id:))
    end

    def resolve_posting_opening_link(**attributes)
      decision = ResolvePostingOpeningLink.call(**attributes)
      decision && resolution_decision_snapshot(decision)
    end

    def fetch_company(company_id:)
      company_snapshot(find_record(Company, company_id, "company_"))
    end

    def fetch_opening(opening_id:)
      opening_snapshot(find_record(JobOpening, opening_id, "opening_"))
    end

    def fetch_posting(posting_id:)
      job_posting_snapshot(find_record(JobPosting, posting_id, "posting_"))
    end

    def fetch_posting_snapshot(posting_snapshot_id:)
      posting_snapshot(find_record(PostingSnapshot, posting_snapshot_id, "posting_snapshot_"))
    end

    def fetch_posting_history(posting_id:)
      posting = find_record(JobPosting, posting_id, "posting_")

      posting.snapshots.order(:observed_at, :created_at).map { posting_snapshot(_1) }.freeze
    end

    def company_snapshot(company)
      {
        id: company.typed_id,
        canonical_name: company.canonical_name,
        website_url: company.website_url,
        primary_domain: company.primary_domain,
        metadata: deep_freeze(company.metadata.deep_dup),
        created_at: company.created_at
      }.freeze
    end
    private_class_method :company_snapshot

    def opening_snapshot(opening)
      {
        id: opening.typed_id,
        primary_company_id: typed_id("company", opening.primary_company_id),
        canonical_title: opening.canonical_title,
        lifecycle_state: opening.lifecycle_state,
        first_seen_at: opening.first_seen_at,
        last_seen_at: opening.last_seen_at,
        closed_at: opening.closed_at,
        metadata: deep_freeze(opening.metadata.deep_dup),
        parties: opening.opening_parties.order(:created_at, :id).map { opening_party_snapshot(_1) }.freeze,
        job_posting_ids: opening.job_postings.order(:created_at, :id).map(&:typed_id).freeze
      }.freeze
    end
    private_class_method :opening_snapshot

    def job_posting_snapshot(posting)
      {
        id: posting.typed_id,
        job_opening_id: typed_id("opening", posting.job_opening_id),
        publisher_company_id: typed_id("company", posting.publisher_company_id),
        source_key: posting.source_key,
        external_id: posting.external_id,
        canonical_url: posting.canonical_url,
        application_url: posting.application_url,
        title: posting.title,
        source_published_at: posting.source_published_at,
        source_updated_at: posting.source_updated_at,
        first_seen_at: posting.first_seen_at,
        last_confirmed_present_at: posting.last_confirmed_present_at,
        missing_since: posting.missing_since,
        lifecycle_state: posting.lifecycle_state,
        description_fingerprint: posting.description_fingerprint,
        metadata: deep_freeze(posting.metadata.deep_dup),
        posting_snapshot_ids: posting.snapshots.order(:observed_at, :created_at).map(&:typed_id).freeze
      }.freeze
    end
    private_class_method :job_posting_snapshot

    def opening_party_snapshot(party)
      {
        id: party.typed_id,
        company_id: typed_id("company", party.company_id),
        role: party.role,
        party_label: party.party_label,
        confidence: party.confidence.to_f,
        evidence: deep_freeze(party.evidence.deep_dup),
        metadata: deep_freeze(party.metadata.deep_dup)
      }.freeze
    end
    private_class_method :opening_party_snapshot

    def posting_snapshot(snapshot)
      {
        id: snapshot.typed_id,
        job_posting_id: typed_id("posting", snapshot.job_posting_id),
        source_observation_id: typed_id("source_observation", snapshot.source_observation_id),
        observed_at: snapshot.observed_at,
        presence_state: snapshot.presence_state,
        title: snapshot.title,
        description_fingerprint: snapshot.description_fingerprint,
        source_published_at: snapshot.source_published_at,
        source_updated_at: snapshot.source_updated_at,
        facts: deep_freeze(snapshot.facts.deep_dup),
        content_digest: snapshot.content_digest,
        normalizer_key: snapshot.normalizer_key,
        normalizer_version: snapshot.normalizer_version,
        metadata: deep_freeze(snapshot.metadata.deep_dup),
        created_at: snapshot.created_at
      }.freeze
    end
    private_class_method :posting_snapshot

    def resolution_decision_snapshot(decision)
      {
        id: decision.typed_id,
        decision_type: decision.decision_type,
        job_posting_id: typed_id("posting", decision.job_posting_id),
        from_job_opening_id: typed_id("opening", decision.from_job_opening_id),
        to_job_opening_id: typed_id("opening", decision.to_job_opening_id),
        confidence: decision.confidence.to_f,
        evidence: deep_freeze(decision.evidence.deep_dup),
        resolver_key: decision.resolver_key,
        resolver_version: decision.resolver_version,
        decided_at: decision.decided_at,
        metadata: deep_freeze(decision.metadata.deep_dup)
      }.freeze
    end
    private_class_method :resolution_decision_snapshot

    def find_record(klass, value, typed_prefix)
      value.to_s.start_with?(typed_prefix) ? klass.find_by_typed_id!(value) : klass.find(value)
    rescue ActiveRecord::RecordNotFound
      raise NotFound, "resource not found"
    end
    private_class_method :find_record

    def typed_id(prefix, uuid)
      uuid && TypeID.from_uuid(prefix, uuid).to_s
    end
    private_class_method :typed_id

    def deep_freeze(value)
      case value
      when Hash
        value.each { |key, nested| key.freeze; deep_freeze(nested) }
      when Array
        value.each { deep_freeze(_1) }
      end
      value.freeze
    end
    private_class_method :deep_freeze
  end
end
