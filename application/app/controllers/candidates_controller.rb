# frozen_string_literal: true

class CandidatesController < InertiaController
  before_action :require_current_organization

  def index
    render inertia: "candidates/index", props: {
      candidates: current_candidates.includes(:language_proficiencies).order(:last_name, :first_name).map { |candidate| candidate_props(candidate) }
    }
  end

  def new
    render inertia: "candidates/new", props: {
      consentStatuses: Candidate::CONSENT_STATUSES,
      languageProficiencyLevels: language_proficiency_levels,
      jobs: current_jobs.includes(project: :client_company).where(status: %w[draft open]).order(:title).map do |job|
        { id: job.typed_id, title: job.title, project: job.project.name, client: job.project.client_company.name }
      end,
      selectedJobId: params[:job_id]
    }
  end

  def show
    candidate = find_current_candidate!(params[:id], includes: [ :language_proficiencies, { applications: { job: { project: :client_company } } } ])
    meetings = candidate.meetings.includes(:interview, :reminder_task, application: { job: { project: :client_company } }).order(scheduled_at: :desc)
    render inertia: "candidates/show", props: {
      candidate: candidate_props(candidate, include_profile: true),
      applications: application_props(candidate),
      meetings: meetings.map { |meeting| meeting_props(meeting) },
      meetingKinds: Meeting::KINDS,
      selectedApplicationId: params[:application_id],
      openMeetingComposer: params[:schedule_meeting] == "1"
    }
  end

  def edit
    candidate = find_current_candidate!(params[:id], includes: :language_proficiencies)
    render inertia: "candidates/edit", props: { candidate: candidate_props(candidate, include_profile: true), consentStatuses: Candidate::CONSENT_STATUSES, languageProficiencyLevels: language_proficiency_levels }
  end

  def create
    candidate = Candidate.new(candidate_params)
    job = find_current_job!(params[:job_id])

    Application.transaction do
      candidate.save!
      set_english_proficiency(candidate)
      application = Application.create!(candidate:, job:, sourced_by: Current.user, stage: "sourced")
      application.stage_events.create!(to_stage: "sourced", moved_by: Current.user, occurred_at: Time.current)
    end
    if candidate.persisted?
      redirect_to candidates_path, notice: "Candidate created"
    end
  rescue ActiveRecord::RecordInvalid => error
    redirect_to new_candidate_path(job_id: params[:job_id]), inertia: { errors: error.record.errors }
  end

  def update
    candidate = find_current_candidate!(params[:id])
    Candidate.transaction do
      candidate.update!(candidate_params.merge(profile_params))
      set_english_proficiency(candidate)
    end
    redirect_to candidate_path(candidate), notice: "Candidate profile updated"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to edit_candidate_path(candidate), inertia: { errors: error.record.errors }
  end

  private

  def current_candidates
    Candidate.for_organization(Current.organization)
  end

  def current_jobs
    Job.for_organization(Current.organization)
  end

  def find_current_candidate!(typed_id, includes: nil)
    relation = current_candidates
    relation = relation.includes(includes) if includes
    relation.find(Candidate.typed_id_value(typed_id))
  end

  def find_current_job!(typed_id)
    current_jobs.find(Job.typed_id_value(typed_id))
  end

  def candidate_params
    params.permit(:first_name, :last_name, :email, :location, :time_zone, :source, :consent_status)
  end

  def profile_params
    params.permit(:linkedin_url, :github_url, :salary_expectation, :availability, :notice_period, :work_authorization, :notes, :skills, :tags).then do |permitted|
      permitted.merge(skills: split_list(permitted[:skills]), tags: split_list(permitted[:tags]))
    end
  end

  def split_list(value)
    value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def candidate_props(candidate, include_profile: false)
    attributes = %i[id first_name last_name email location time_zone source consent_status]
    attributes += %i[linkedin_url github_url salary_expectation availability notice_period work_authorization skills tags notes] if include_profile
    candidate.slice(*attributes).merge(id: candidate.typed_id, english_proficiency: english_proficiency_props(candidate))
  end

  def application_props(candidate)
    candidate.applications.map do |application|
      { id: application.typed_id, stage: application.stage, job: application.job.title, project: application.job.project.name, client: application.job.project.client_company.name }
    end
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
      notes: meeting.notes,
      interview_id: meeting.interview&.typed_id,
      application: meeting.application && {
        id: meeting.application.typed_id,
        job: meeting.application.job.title,
        project: meeting.application.job.project.name,
        client: meeting.application.job.project.client_company.name
      }
    }
  end

  def set_english_proficiency(candidate)
    return unless params.key?(:english_proficiency_level)

    level = params[:english_proficiency_level].presence
    proficiency = candidate.language_proficiencies.find_or_initialize_by(language_code: "en")
    return proficiency.destroy! if level.blank? && proficiency.persisted?
    return if level.blank?

    proficiency.level = level
    proficiency.save!
  end

  def language_proficiency_levels
    LanguageProficiency::CEFR_LEVELS.keys.map do |level|
      { code: helpers.language_proficiency_label(level, style: :code), value: level, label: helpers.language_proficiency_label(level, style: :label), full_label: helpers.language_proficiency_label(level) }
    end
  end

  def english_proficiency_props(candidate)
    level = candidate.english_proficiency_level
    return unless level

    {
      value: level,
      code: helpers.language_proficiency_label(level, style: :code),
      label: helpers.language_proficiency_label(level, style: :label),
      full_label: helpers.language_proficiency_label(level)
    }
  end
end
