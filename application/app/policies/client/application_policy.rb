# frozen_string_literal: true

class Client::ApplicationPolicy < ApplicationPolicy
  if defined?(Enforceable)
    include Enforceable
    enforceable :show?, scope_name: :default
  end

  def index?
    client_membership?
  end

  def show?
    client_membership? && record.client_visible? && record.stage.in?(Application::CLIENT_VISIBLE_STAGES) && record.client_company.id == membership.client_company_id
  end

  def decide?
    show? && membership.role == "client_hiring_manager" && record.client_decision.nil? && record.stage.in?(%w[presented client_interviews])
  end

  relation_scope do |relation|
    next relation.none unless client_membership?

    relation.client_visible_to_client.joins(job: :project).where(projects: { client_company_id: membership.client_company_id })
  end

  private

  def client_membership?
    user.present? && membership&.client_portal?
  end
end
