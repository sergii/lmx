# frozen_string_literal: true

module MarketCatalog
  class PostingLifecyclePolicy
    VERSION = "v1"
    SUPPORTED_VERSIONS = [ VERSION ].freeze
    DEFAULT_PROBABLY_CLOSED_AFTER_MISSES = 3
    DEFAULT_CLOSED_AFTER_MISSES = nil

    ENV_VERSION = "LMX_POSTING_LIFECYCLE_POLICY_VERSION"
    ENV_PROBABLY_CLOSED_AFTER = "LMX_POSTING_PROBABLY_CLOSED_AFTER_MISSES"
    ENV_CLOSED_AFTER = "LMX_POSTING_CLOSED_AFTER_MISSES"

    attr_reader :version, :probably_closed_after_misses, :closed_after_misses

    class << self
      def from_env(env: ENV)
        new(
          version: env.fetch(ENV_VERSION, VERSION),
          probably_closed_after_misses: integer_setting(
            env[ENV_PROBABLY_CLOSED_AFTER],
            default: DEFAULT_PROBABLY_CLOSED_AFTER_MISSES,
            name: ENV_PROBABLY_CLOSED_AFTER
          ),
          closed_after_misses: optional_integer_setting(
            env[ENV_CLOSED_AFTER],
            name: ENV_CLOSED_AFTER
          )
        )
      end

      private

      def integer_setting(value, default:, name:)
        return default if value.blank?

        Integer(value, 10)
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{name} must be an integer"
      end

      def optional_integer_setting(value, name:)
        return if value.blank?

        integer_setting(value, default: nil, name:)
      end
    end

    def initialize(
      version: VERSION,
      probably_closed_after_misses: DEFAULT_PROBABLY_CLOSED_AFTER_MISSES,
      closed_after_misses: DEFAULT_CLOSED_AFTER_MISSES
    )
      @version = version.to_s.strip
      @probably_closed_after_misses = normalize_count(probably_closed_after_misses, "probably_closed_after_misses")
      @closed_after_misses = normalize_optional_count(closed_after_misses, "closed_after_misses")

      validate!
      freeze
    end

    def state_for_missing_count(count)
      count = Integer(count)
      raise ArgumentError, "missing count must not be negative" if count.negative?

      return "closed" if closed_after_misses && count >= closed_after_misses
      return "probably_closed" if count >= probably_closed_after_misses

      "missing"
    end

    def snapshot
      {
        "version" => version,
        "probably_closed_after_misses" => probably_closed_after_misses,
        "closed_after_misses" => closed_after_misses
      }.freeze
    end

    private

    def normalize_count(value, name)
      Integer(value).tap do |count|
        raise ArgumentError, "#{name} must be at least 2" if count < 2
      end
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{name} must be an integer of at least 2"
    end

    def normalize_optional_count(value, name)
      return if value.nil?

      normalize_count(value, name)
    end

    def validate!
      unless SUPPORTED_VERSIONS.include?(version)
        raise ArgumentError, "unsupported posting lifecycle policy version #{version.inspect}"
      end

      return unless closed_after_misses && closed_after_misses < probably_closed_after_misses

      raise ArgumentError, "closed_after_misses must be greater than or equal to probably_closed_after_misses"
    end
  end
end
