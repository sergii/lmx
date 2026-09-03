# frozen_string_literal: true

module MarketCatalog
  class OpeningParty < ApplicationRecord
    self.table_name = "market_catalog_opening_parties"

    include TypedId

    ROLES = %w[
      direct_employer
      end_client
      staffing_vendor
      recruiting_agency
      employer_of_record
      contracting_party
    ].freeze

    uses_typed_id "opening_party"

    belongs_to :job_opening,
      class_name: "MarketCatalog::JobOpening",
      inverse_of: :opening_parties
    belongs_to :company,
      class_name: "MarketCatalog::Company",
      inverse_of: :opening_parties,
      optional: true

    normalizes :role, with: -> { _1.strip.downcase }
    normalizes :party_label, with: -> { _1.strip.gsub(/\s+/, " ").presence }

    validates :role, inclusion: { in: ROLES }
    validates :confidence,
      numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
    validate :company_or_label_present
    validate :evidence_is_array

    private

    def company_or_label_present
      return if company.present? || party_label.present?

      errors.add(:base, "opening party requires a company or descriptive label")
    end

    def evidence_is_array
      errors.add(:evidence, "must be an array") unless evidence.is_a?(Array)
    end
  end
end
