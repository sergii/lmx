# frozen_string_literal: true

module MarketCatalog
  class CreateOpening
    class << self
      def call(canonical_title:, first_seen_at:, primary_company_id: nil, metadata: {})
        JobOpening.create!(
          canonical_title:,
          primary_company: find_company(primary_company_id),
          first_seen_at:,
          last_seen_at: first_seen_at,
          metadata: metadata || {}
        )
      end

      private

      def find_company(value)
        return if value.blank?
        return value if value.is_a?(Company)

        value.to_s.start_with?("company_") ? Company.find_by_typed_id!(value) : Company.find(value)
      end
    end
  end
end
