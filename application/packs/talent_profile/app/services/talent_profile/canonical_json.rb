# frozen_string_literal: true

require "digest"

module TalentProfile
  module CanonicalJson
    module_function

    def normalize(value)
      case value
      when Hash
        value.to_h.transform_keys(&:to_s).sort.to_h.transform_values { normalize(_1) }
      when Array
        value.map { normalize(_1) }
      else
        value
      end
    end

    def digest(value)
      Digest::SHA256.hexdigest(JSON.generate(normalize(value)))
    end
  end
end
