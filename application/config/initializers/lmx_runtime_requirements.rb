# frozen_string_literal: true

Rails.application.config.after_initialize do
  Delivery::RuntimeRequirements.validate!
end
