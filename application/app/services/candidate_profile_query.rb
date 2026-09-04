# frozen_string_literal: true

require "time"

class CandidateProfileQuery
  class << self
    def call(**attributes)
      new(**attributes).call
    end
  end

  def initialize(user_id:, talent_api: TalentProfile::Api)
    @user_id = user_id
    @talent_api = talent_api
  end

  def call
    candidate = talent_api.fetch_candidate_for_user(user_id:)
    versions = talent_api.fetch_profile_versions(candidate_id: candidate.fetch(:id))

    {
      candidate: candidate_props(candidate),
      latest_profile: versions.first && profile_version_props(versions.first),
      versions: versions.map { profile_version_props(_1) }
    }
  rescue TalentProfile::Api::NotFound
    {
      candidate: nil,
      latest_profile: nil,
      versions: []
    }
  end

  private

  attr_reader :user_id, :talent_api

  def candidate_props(candidate)
    {
      id: candidate.fetch(:id),
      linked_user_id: candidate[:linked_user_id],
      first_name: candidate[:first_name],
      last_name: candidate[:last_name],
      email: candidate[:email]
    }
  end

  def profile_version_props(version)
    {
      id: version.fetch(:id),
      candidate_id: version.fetch(:candidate_id),
      version_number: version.fetch(:version_number),
      schema_version: version.fetch(:schema_version),
      profile: version.fetch(:profile),
      content_digest: version.fetch(:content_digest),
      origin: version.fetch(:origin),
      accepted_by_user_id: version[:accepted_by_user_id],
      accepted_at: iso8601(version[:accepted_at]),
      evidence_ids: version.fetch(:evidence_ids),
      created_at: iso8601(version[:created_at])
    }
  end

  def iso8601(value)
    return if value.nil?
    return value.iso8601 if value.respond_to?(:iso8601)

    Time.iso8601(value.to_s).iso8601
  end
end
