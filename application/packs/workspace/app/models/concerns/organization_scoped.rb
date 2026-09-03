# frozen_string_literal: true

module OrganizationScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :organization

    before_validation :assign_current_organization, on: :create
    validates :organization_id, presence: true
  end

  class_methods do
    def for_organization(organization)
      where(organization_id: organization.id)
    end
  end

  private

  def assign_current_organization
    self.organization_id ||= Current.organization&.id
  end
end
