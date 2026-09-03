# frozen_string_literal: true

module MarketCatalog
  class RecordPosting
    class IdentityConflict < StandardError; end

    class << self
      def call(source_key:, title:, observed_at:, external_id: nil, canonical_url: nil, application_url: nil,
        publisher_company_id: nil, source_published_at: nil, source_updated_at: nil,
        description_fingerprint: nil, metadata: {})
        new(
          source_key:,
          title:,
          observed_at:,
          external_id:,
          canonical_url:,
          application_url:,
          publisher_company_id:,
          source_published_at:,
          source_updated_at:,
          description_fingerprint:,
          metadata:
        ).call
      end
    end

    def initialize(source_key:, title:, observed_at:, external_id:, canonical_url:, application_url:,
      publisher_company_id:, source_published_at:, source_updated_at:, description_fingerprint:, metadata:)
      @source_key = source_key.to_s.strip.downcase
      @title = title.to_s.strip
      @observed_at = normalize_time(observed_at)
      @external_id = external_id.to_s.strip.presence
      @canonical_url = canonical_url.to_s.strip.presence
      @application_url = application_url.to_s.strip.presence
      @publisher_company = find_company(publisher_company_id)
      @source_published_at = normalize_time(source_published_at)
      @source_updated_at = normalize_time(source_updated_at)
      @description_fingerprint = description_fingerprint.to_s.strip.downcase.presence
      @metadata = metadata || {}
    end

    def call
      JobPosting.transaction do
        posting = find_existing_posting

        if posting
          posting.with_lock do
            current_observation = observed_at >= posting.last_confirmed_present_at
            before = material_state(posting)
            refresh_posting(posting)

            if current_observation && material_state(posting) != before
              EmitPostingEvent.call(posting:, event_type: "JobPostingUpdated", occurred_at: observed_at)
            end

            posting
          end
        else
          posting, created = create_posting
          if created
            EmitPostingEvent.call(posting:, event_type: "JobPostingDiscovered", occurred_at: observed_at)
          end
          posting
        end
      end
    end

    private

    attr_reader :source_key, :title, :observed_at, :external_id, :canonical_url, :application_url,
      :publisher_company, :source_published_at, :source_updated_at, :description_fingerprint, :metadata

    def find_existing_posting
      matches = []
      matches << JobPosting.find_by(source_key:, external_id:) if external_id

      canonical_digest = JobPosting.url_digest(canonical_url)
      if canonical_digest
        matches << JobPosting.find_by(source_key:, canonical_url_digest: canonical_digest)
      end

      application_digest = JobPosting.url_digest(application_url)
      if application_digest
        application_matches = JobPosting.where(source_key:, application_url_digest: application_digest).limit(2).to_a
        matches << application_matches.first if application_matches.one?
      end

      matches = matches.compact.uniq
      raise IdentityConflict, "identity signals point to different job postings" if matches.many?

      matches.first
    end

    def create_posting
      posting = JobPosting.create!(
        source_key:,
        external_id:,
        canonical_url:,
        application_url:,
        title:,
        publisher_company:,
        source_published_at:,
        source_updated_at:,
        first_seen_at: observed_at,
        last_confirmed_present_at: observed_at,
        description_fingerprint:,
        metadata:
      )
      [ posting, true ]
    rescue ActiveRecord::RecordNotUnique
      posting = find_existing_posting
      raise unless posting

      [ posting.with_lock { refresh_posting(posting) }, false ]
    end

    def refresh_posting(posting)
      validate_stable_identity!(posting)
      validate_publisher!(posting)

      newest_observation = observed_at >= posting.last_confirmed_present_at
      attributes = {
        external_id: posting.external_id.presence || external_id,
        canonical_url: choose_url(posting.canonical_url, canonical_url, newest_observation),
        application_url: choose_url(posting.application_url, application_url, newest_observation),
        publisher_company: posting.publisher_company || publisher_company,
        source_published_at: earliest(posting.source_published_at, source_published_at),
        source_updated_at: latest(posting.source_updated_at, source_updated_at),
        first_seen_at: earliest(posting.first_seen_at, observed_at),
        last_confirmed_present_at: latest(posting.last_confirmed_present_at, observed_at)
      }

      if newest_observation
        attributes[:title] = title
        attributes[:description_fingerprint] = description_fingerprint || posting.description_fingerprint
        attributes[:metadata] = posting.metadata.merge(metadata)
        attributes[:missing_since] = nil
        attributes[:lifecycle_state] = "reappeared" if %w[missing probably_closed closed].include?(posting.lifecycle_state)
      end

      posting.update!(attributes)
      posting
    end

    def material_state(posting)
      [
        posting.title,
        posting.canonical_url,
        posting.application_url,
        posting.publisher_company_id,
        posting.source_updated_at&.utc&.iso8601(6),
        posting.description_fingerprint,
        posting.lifecycle_state
      ]
    end

    def validate_stable_identity!(posting)
      return if external_id.blank? || posting.external_id.blank? || posting.external_id == external_id

      raise IdentityConflict, "source external ID conflicts with existing posting identity"
    end

    def validate_publisher!(posting)
      return if publisher_company.blank? || posting.publisher_company.blank? || posting.publisher_company == publisher_company

      raise IdentityConflict, "publisher company conflicts with existing posting identity"
    end

    def choose_url(existing, incoming, newest_observation)
      return incoming if existing.blank?
      return existing if incoming.blank? || !newest_observation

      incoming
    end

    def earliest(left, right)
      [ left, right ].compact.min
    end

    def latest(left, right)
      [ left, right ].compact.max
    end

    def find_company(value)
      return if value.blank?
      return value if value.is_a?(Company)

      value.to_s.start_with?("company_") ? Company.find_by_typed_id!(value) : Company.find(value)
    end

    def normalize_time(value)
      return if value.blank?
      return value.in_time_zone if value.respond_to?(:in_time_zone)

      Time.zone.parse(value.to_s)
    end
  end
end
