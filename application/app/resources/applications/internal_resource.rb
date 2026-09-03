# frozen_string_literal: true

class Applications::InternalResource
  include Alba::Resource

  attributes :stage, :client_visible

  attribute :id do |application|
    application.typed_id
  end

  attribute :candidate do |application|
    application.candidate.slice(:first_name, :last_name, :email, :source, :consent_status, :skills, :tags, :notes)
  end
end
