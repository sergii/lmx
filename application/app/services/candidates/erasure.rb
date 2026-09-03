# frozen_string_literal: true

module Candidates
  class Erasure
    def self.call(candidate:, reason:)
      new(candidate:, reason:).call
    end

    def initialize(candidate:, reason:)
      @candidate = candidate
      @reason = reason
    end

    def call
      return candidate if candidate.erased_at?

      Application.transaction do
        applications = candidate.applications
        interviews = candidate.interviews
        assessments = InterviewAssessment.where(interview_id: interviews.select(:id))
        competency_assessments = CompetencyAssessment.where(interview_assessment_id: assessments.select(:id))
        evidences = Evidence.where(interview_id: interviews.select(:id))
        meetings = candidate.meetings
        reminder_task_ids = meetings.where.not(reminder_task_id: nil).select(:reminder_task_id)

        CompetencyAssessmentEvidence.where(competency_assessment_id: competency_assessments.select(:id)).delete_all
        CompetencyAssessmentEvidence.where(evidence_id: evidences.select(:id)).delete_all
        CompetencyAssessment.where(id: competency_assessments.select(:id)).delete_all
        Evidence.where(id: evidences.select(:id)).delete_all
        InterviewAssessment.where(id: assessments.select(:id)).delete_all
        Interview.where(id: interviews.select(:id)).delete_all
        Meeting.where(id: meetings.select(:id)).update_all(reminder_task_id: nil)
        Meeting.where(id: meetings.select(:id)).delete_all
        Task.where(id: reminder_task_ids).delete_all
        ApplicationStageEvent.where(application_id: applications.select(:id)).delete_all
        Application.where(candidate:).delete_all
        candidate.update!(
          first_name: "Erased", last_name: "Candidate", email: nil, location: nil, time_zone: nil,
          source: nil, linkedin_url: nil, github_url: nil, salary_expectation: nil, availability: nil,
          notice_period: nil, work_authorization: nil, skills: [], tags: [], notes: nil,
          consent_status: "withdrawn", erased_at: Time.current
        )
        AuditEvent.create!(action: "candidate.erased", subject_type: "Candidate", subject_id: candidate.id, metadata: { reason: reason }, occurred_at: Time.current)
      end
      candidate
    end

    private

    attr_reader :candidate, :reason
  end
end
