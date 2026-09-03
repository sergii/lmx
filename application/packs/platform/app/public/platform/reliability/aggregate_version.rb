# frozen_string_literal: true

module Platform
  module Reliability
    module AggregateVersion
      module_function

      def call(aggregate_type:, aggregate_id:)
        organization_id = current_organization_id!

        Platform::DomainEvent
          .where(
            organization_id:,
            aggregate_type: aggregate_type.to_s,
            aggregate_id: aggregate_id.to_s
          )
          .maximum(:aggregate_version)
          .to_i
      end

      def current_organization_id!
        value = ActiveRecord::Base.connection.select_value(
          "SELECT current_setting('app.current_organization', true)"
        )
        raise Platform::Reliability::Api::MissingWorkspace, "workspace database scope is required" if value.blank?

        value
      end
      private_class_method :current_organization_id!
    end
  end
end
