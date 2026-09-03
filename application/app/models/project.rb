# frozen_string_literal: true

class Project < ApplicationRecord
  include TypedId
  include OrganizationScoped

  uses_typed_id "project"


  belongs_to :client_company
  has_many :jobs, dependent: :restrict_with_error
  validates :name, presence: true
  validate :client_belongs_to_current_organization

  private

  def client_belongs_to_current_organization
    errors.add(:client_company, "must belong to the current organization") if client_company && client_company.organization_id != organization_id
  end
end
