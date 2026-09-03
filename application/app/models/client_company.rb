# frozen_string_literal: true

class ClientCompany < ApplicationRecord
  include TypedId
  include OrganizationScoped

  uses_typed_id "client"


  has_many :projects, dependent: :restrict_with_error
  validates :name, presence: true
end
