# frozen_string_literal: true

module MarketCatalog
  class CreateCompany
    class << self
      def call(canonical_name:, website_url: nil, primary_domain: nil, metadata: {})
        Company.create!(
          canonical_name:,
          website_url: website_url.to_s.strip.presence,
          primary_domain: normalize_domain(primary_domain.presence || domain_from(website_url)),
          metadata: metadata || {}
        )
      end

      private

      def domain_from(website_url)
        return if website_url.blank?

        URI.parse(website_url.to_s).host
      rescue URI::InvalidURIError
        nil
      end

      def normalize_domain(value)
        value.to_s.strip.downcase.delete_suffix(".").presence
      end
    end
  end
end
