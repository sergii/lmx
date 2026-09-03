# frozen_string_literal: true

module Intelligence
  class MatchAssessment < ApplicationRecord
    self.table_name = "intelligence_match_assessments"

    include TypedId

    uses_typed_id "match_assessment"

    validates :organization_id, presence: true
    validates :candidate_id, :candidate_profile_version_id, :job_opening_id, presence: true
    validates :candidate_profile_content_digest,
      presence: true,
      format: { with: /\A[0-9a-f]{64}\z/ }
    validates :version_number, numericality: { only_integer: true, greater_than: 0 }
    validates :opening_evidence_cutoff, :scoring_policy_version, :generated_at, presence: true
    validates :opportunity_score, :action_priority, numericality: true, allow_nil: true

    validate :json_objects_are_objects
    validate :json_lists_are_arrays

    def readonly?
      persisted?
    end

    private

    def json_objects_are_objects
      errors.add(:opening_snapshot, "must be a JSON object") unless opening_snapshot.is_a?(Hash)
      errors.add(:score_details, "must be a JSON object") unless score_details.is_a?(Hash)
    end

    def json_lists_are_arrays
      %i[strengths gaps risks interview_angles evidence_references].each do |attribute|
        errors.add(attribute, "must be a JSON array") unless public_send(attribute).is_a?(Array)
      end
    end
  end
end
