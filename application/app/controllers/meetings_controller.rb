# frozen_string_literal: true

class MeetingsController < InertiaController
  before_action :require_current_organization

  def index
    authorize! Meeting

    meetings = Meeting.includes(:candidate, :reminder_task, application: { job: { project: :client_company } })
                      .order(scheduled_at: :asc)
    render inertia: "meetings/index", props: { meetings: meetings.map { |meeting| meeting_props(meeting) } }
  end

  def create
    candidate = Candidate.find_by_typed_id!(params[:candidate_id])
    application = selected_application_for(candidate)
    meeting = Meeting.new(meeting_params.merge(candidate:, application:, created_by: Current.user))
    authorize! meeting

    Meeting.transaction do
      meeting.save!
      create_reminder_task!(meeting) if meeting.scheduled?
    end

    redirect_to candidate_path(candidate), notice: "Meeting scheduled"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to candidate_path(params[:candidate_id]), inertia: { errors: error.record.errors }
  end

  def update
    meeting = Meeting.find_by_typed_id!(params[:id])
    authorize! meeting

    Meeting.transaction do
      meeting.update!(status: params.require(:status))
      update_reminder_task!(meeting)
    end

    redirect_to candidate_path(meeting.candidate), notice: "Meeting marked #{meeting.status.humanize.downcase}"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to candidate_path(meeting.candidate), inertia: { errors: error.record.errors }
  end

  private

  def meeting_params
    params.permit(:kind, :scheduled_at, :duration_minutes, :meeting_url, :notes)
  end

  def selected_application_for(candidate)
    return unless params[:application_id].present?

    application = Application.find_by_typed_id!(params[:application_id])
    raise ActiveRecord::RecordNotFound unless application.candidate_id == candidate.id

    application
  end

  def create_reminder_task!(meeting)
    assignee = meeting.application&.sourced_by || Current.user
    task = Task.create!(
      created_by: Current.user,
      assigned_to: assignee,
      title: "#{meeting.kind.humanize} with #{meeting.candidate.first_name} #{meeting.candidate.last_name}",
      due_on: meeting.scheduled_at.to_date
    )
    meeting.update!(reminder_task: task)
  end

  def update_reminder_task!(meeting)
    return unless meeting.reminder_task

    completed_at = meeting.status == "scheduled" ? nil : Time.current
    meeting.reminder_task.update!(completed_at:)
  end

  def meeting_props(meeting)
    {
      id: meeting.typed_id,
      kind: meeting.kind,
      status: meeting.status,
      sequence: meeting.sequence,
      scheduled_at: meeting.scheduled_at.iso8601,
      duration_minutes: meeting.duration_minutes,
      meeting_url: meeting.meeting_url,
      candidate: {
        id: meeting.candidate.typed_id,
        name: [ meeting.candidate.first_name, meeting.candidate.last_name ].join(" "),
        email: meeting.candidate.email
      },
      application: meeting.application && {
        id: meeting.application.typed_id,
        job: meeting.application.job.title,
        project: meeting.application.job.project.name,
        client: meeting.application.job.project.client_company.name
      }
    }
  end
end
