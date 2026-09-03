# frozen_string_literal: true

class InterviewsController < InertiaController
  before_action :require_current_organization

  def show
    interview = authorized_scope(Interview.includes(:candidate, :meeting, application: { job: :project }, assessments: :assessor), with: InterviewPolicy).find_by_typed_id!(params[:id])
    authorize! interview, to: :show?, with: InterviewPolicy

    render inertia: "interviews/show", props: {
      interview: Interviews::InternalResource.new(interview).serializable_hash,
      assessments: interview.assessments.order(created_at: :desc).map { |assessment| assessment_props(assessment) },
      assessmentStatuses: InterviewAssessment::STATUSES
    }
  end

  def create
    candidate = Candidate.find_by_typed_id!(params[:candidate_id])
    application = selected_application_for(candidate)
    meeting = selected_meeting_for(candidate)
    interview = Interview.new(interview_params.merge(candidate:, application:, meeting:, created_by: Current.user))
    authorize! interview, to: :create?, with: InterviewPolicy
    interview.save!

    redirect_to interview_path(interview), notice: "Interview recorded"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to candidate_path(params[:candidate_id]), inertia: { errors: error.record.errors }
  end

  private

  def interview_params
    params.permit(:template_name, :language, :status, :interviewer_notes, :transcript, :recording_url, :completed_at)
  end

  def selected_application_for(candidate)
    return unless params[:application_id].present?

    application = Application.find_by_typed_id!(params[:application_id])
    raise ActiveRecord::RecordNotFound unless application.candidate_id == candidate.id

    application
  end

  def selected_meeting_for(candidate)
    return unless params[:meeting_id].present?

    meeting = Meeting.find_by_typed_id!(params[:meeting_id])
    raise ActiveRecord::RecordNotFound unless meeting.candidate_id == candidate.id

    meeting
  end

  def assessment_props(assessment)
    {
      id: assessment.typed_id,
      status: assessment.status,
      assessor: assessment.assessor.name,
      overall_level: assessment.overall_level,
      rating: assessment.rating,
      recommendation: assessment.recommendation,
      strong_sides: assessment.strong_sides,
      improvement_areas: assessment.improvement_areas,
      overall_comments: assessment.overall_comments
    }
  end
end
