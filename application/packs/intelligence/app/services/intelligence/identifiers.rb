# frozen_string_literal: true

module Intelligence
  module Identifiers
    module_function

    def uuid(value, prefix:)
      typed_id = TypeID.from_string(value.to_s)
      return typed_id.uuid.to_s if typed_id.prefix == prefix

      raise ArgumentError, "Invalid #{prefix} identifier"
    rescue TypeID::Error
      raise ArgumentError, "Invalid #{prefix} identifier"
    end
  end
end
