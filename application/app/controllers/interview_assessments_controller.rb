# frozen_string_literal: true

class InterviewAssessmentsController < InertiaController
  before_action :require_current_organization

  def create
    interview = authorized_scope(Interview.all, with: InterviewPolicy).find_by_typed_id(params[:interview_id])
    return head :not_found unless interview

    authorize! interview, to: :show?, with: InterviewPolicy
    assessment = InterviewAssessment.new(assessment_params.merge(interview:, assessor: Current.user))
    authorize! assessment, to: :create?, with: InterviewAssessmentPolicy
    assessment.save!

    redirect_to interview_path(interview), notice: "Assessment saved"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to interview_path(interview), inertia: { errors: error.record.errors }
  end

  private

  def assessment_params
    params.permit(:status, :overall_level, :rating, :recommendation, :strong_sides, :improvement_areas, :overall_comments)
  end
end
