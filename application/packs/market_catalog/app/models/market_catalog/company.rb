# frozen_string_literal: true

module MarketCatalog
  class Company < ApplicationRecord
    self.table_name = "market_catalog_companies"

    include TypedId

    uses_typed_id "company"

    has_many :job_openings,
      class_name: "MarketCatalog::JobOpening",
      foreign_key: :primary_company_id,
      inverse_of: :primary_company,
      dependent: :restrict_with_exception
    has_many :opening_parties,
      class_name: "MarketCatalog::OpeningParty",
      inverse_of: :company,
      dependent: :restrict_with_exception
    has_many :published_job_postings,
      class_name: "MarketCatalog::JobPosting",
      foreign_key: :publisher_company_id,
      inverse_of: :publisher_company,
      dependent: :restrict_with_exception

    normalizes :canonical_name, with: -> { _1.strip.gsub(/\s+/, " ") }
    normalizes :primary_domain, with: -> { _1.strip.downcase.delete_suffix(".").presence }

    before_validation :derive_normalized_name

    validates :canonical_name, presence: true
    validates :normalized_name, presence: true
    validates :website_url,
      format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) },
      allow_blank: true
    validates :primary_domain,
      format: { with: /\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/i },
      allow_blank: true

    private

    def derive_normalized_name
      self.normalized_name = canonical_name.to_s.strip.downcase.gsub(/\s+/, " ")
    end
  end
end
