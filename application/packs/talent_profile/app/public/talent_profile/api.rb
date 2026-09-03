# frozen_string_literal: true

module TalentProfile
  module Api
    class Error < StandardError; end
    class NotFound < Error; end

    module_function

    def create_candidate(**attributes)
      candidate, profile_version = CreateCandidate.call(**attributes)

      {
        candidate: candidate_snapshot(candidate),
        profile_version: profile_version_snapshot(profile_version)
      }.freeze
    end

    def record_evidence(**attributes)
      evidence_snapshot(RecordEvidence.call(**attributes))
    end

    def create_profile_version(**attributes)
      profile_version_snapshot(CreateProfileVersion.call(**attributes))
    end

    def fetch_candidate(candidate_id:)
      workspace = WorkspaceGuard.current!
      candidate = Candidate.for_organization(workspace).find(Identifiers.uuid(candidate_id, prefix: "candidate"))

      candidate_snapshot(candidate).merge(
        profile_version: candidate.latest_profile_version && profile_version_snapshot(candidate.latest_profile_version)
      ).freeze
    rescue ActiveRecord::RecordNotFound
      raise NotFound, "candidate not found"
    end

    def fetch_latest_profile(candidate_id:)
      workspace = WorkspaceGuard.current!
      candidate_uuid = Identifiers.uuid(candidate_id, prefix: "candidate")
      version = CandidateProfileVersion.for_organization(workspace)
        .where(candidate_id: candidate_uuid)
        .order(version_number: :desc)
        .first!

      profile_version_snapshot(version)
    rescue ActiveRecord::RecordNotFound
      raise NotFound, "candidate profile not found"
    end

    def fetch_profile_version(candidate_id:, profile_version_id:)
      workspace = WorkspaceGuard.current!
      candidate_uuid = Identifiers.uuid(candidate_id, prefix: "candidate")
      version_uuid = Identifiers.uuid(profile_version_id, prefix: "candidate_profile_version")
      version = CandidateProfileVersion.for_organization(workspace).find_by!(id: version_uuid, candidate_id: candidate_uuid)

      profile_version_snapshot(version)
    rescue ActiveRecord::RecordNotFound
      raise NotFound, "candidate profile version not found"
    end

    def candidate_snapshot(candidate)
      {
        id: candidate.typed_id,
        linked_user_id: typed_id("user", candidate.linked_user_id),
        first_name: candidate.first_name,
        last_name: candidate.last_name,
        email: candidate.email
      }.freeze
    end
    private_class_method :candidate_snapshot

    def evidence_snapshot(evidence)
      {
        id: evidence.typed_id,
        candidate_id: typed_id("candidate", evidence.candidate_id),
        source_type: evidence.source_type,
        source_reference: evidence.source_reference,
        claim: evidence.claim,
        confidence: evidence.confidence&.to_f,
        observed_at: evidence.observed_at,
        provenance: deep_freeze(evidence.provenance.deep_dup)
      }.freeze
    end
    private_class_method :evidence_snapshot

    def profile_version_snapshot(version)
      {
        id: version.typed_id,
        candidate_id: typed_id("candidate", version.candidate_id),
        version_number: version.version_number,
        schema_version: version.schema_version,
        profile: deep_freeze(version.profile_data.deep_dup),
        content_digest: version.content_digest,
        origin: version.origin,
        accepted_by_user_id: typed_id("user", version.accepted_by_user_id),
        accepted_at: version.accepted_at,
        evidence_ids: version.candidate_evidences.map(&:typed_id).freeze,
        created_at: version.created_at
      }.freeze
    end
    private_class_method :profile_version_snapshot

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
