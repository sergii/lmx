# frozen_string_literal: true

module TalentProfile
  class CandidateEvidence < ApplicationRecord
    self.table_name = "candidate_evidences"

    include TypedId
    include OrganizationScoped

    uses_typed_id "candidate_evidence"

    belongs_to :candidate, class_name: "TalentProfile::Candidate", inverse_of: :evidences

    validates :source_type, presence: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }
    validates :claim, presence: true
    validates :confidence, numericality: { in: 0..1 }, allow_nil: true
    validate :candidate_belongs_to_workspace

    normalizes :source_type, with: -> { _1.strip.downcase }
    normalizes :source_reference, with: -> { _1.strip.presence }

    def readonly?
      persisted?
    end

    private

    def candidate_belongs_to_workspace
      return unless candidate && organization_id
      return if candidate.organization_id == organization_id

      errors.add(:candidate, "must belong to the current workspace")
    end
  end
end
