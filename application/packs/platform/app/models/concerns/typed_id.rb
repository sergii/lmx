# frozen_string_literal: true

module TypedId
  extend ActiveSupport::Concern

  class_methods do
    def uses_typed_id(prefix)
      class_attribute :typed_id_prefix, default: prefix
    end

    def typed_id_value(value)
      typed_id = TypeID.from_string(value.to_s)
      return typed_id.uuid.to_s if typed_id.prefix == typed_id_prefix

      raise ActiveRecord::RecordNotFound, "Invalid #{typed_id_prefix} identifier"
    rescue TypeID::Error
      raise ActiveRecord::RecordNotFound, "Invalid #{typed_id_prefix} identifier"
    end

    def find_by_typed_id(value)
      find_by(id: typed_id_value(value))
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def find_by_typed_id!(value)
      find(typed_id_value(value))
    end
  end

  def typed_id
    TypeID.from_uuid(self.class.typed_id_prefix, id).to_s
  end

  def to_param
    typed_id
  end
end
