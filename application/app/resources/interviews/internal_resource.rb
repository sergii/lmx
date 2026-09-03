# frozen_string_literal: true

class Interviews::InternalResource
  include Alba::Resource

  attribute :id do |interview|
    interview.typed_id
  end

  attributes :status, :template_name, :language, :interviewer_notes, :transcript, :recording_url, :completed_at

  attribute :candidate do |interview|
    { id: interview.candidate.typed_id, name: "#{interview.candidate.first_name} #{interview.candidate.last_name}" }
  end

  attribute :application do |interview|
    next unless interview.application

    { id: interview.application.typed_id, role: interview.application.job.title }
  end

  attribute :meeting do |interview|
    next unless interview.meeting

    { id: interview.meeting.typed_id, status: interview.meeting.status, scheduled_at: interview.meeting.scheduled_at.iso8601 }
  end
end
