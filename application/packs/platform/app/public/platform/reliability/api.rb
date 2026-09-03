# frozen_string_literal: true

require "digest"

module Platform
  module Reliability
    module Api
      class Error < StandardError; end
      class InvalidInput < Error; end
      class MissingWorkspace < Error; end
      class NotFound < Error; end
      class IdempotencyConflict < Error; end
      class ConcurrencyConflict < Error; end

      DEFAULT_OUTBOX_LEASE = 5.minutes

      module_function

      def receive_command(
        message_id:,
        command_id:,
        idempotency_key:,
        command_name:,
        interface:,
        client:,
        principal:,
        payload:,
        command_version: 1,
        credential: nil,
        actor: nil,
        executor: nil,
        correlation_id: nil,
        causation_id: nil,
        payload_reference: nil,
        received_at: Time.current
      )
        organization_id = current_organization_id!
        attributes = normalize_command_attributes(
          organization_id:,
          message_id:,
          command_id:,
          idempotency_key:,
          command_name:,
          command_version:,
          interface:,
          client:,
          principal:,
          credential:,
          actor:,
          executor:,
          correlation_id:,
          causation_id:,
          payload:,
          payload_reference:,
          received_at:
        )

        message = Platform::InboxMessage.create!(attributes)
        deep_freeze(duplicate: false, command: inbox_snapshot(message))
      rescue ActiveRecord::RecordNotUnique
        duplicate = duplicate_inbox_message(attributes)
        verify_idempotent_duplicate!(duplicate, attributes)
        deep_freeze(duplicate: true, command: inbox_snapshot(duplicate))
      end

      def start_command(command_id:, started_at: Time.current)
        Platform::InboxMessage.transaction do
          message = find_inbox_by_command!(command_id, lock: true)
          return inbox_snapshot(message) if message.status == "succeeded"

          message.update!(
            status: "processing",
            attempt_count: message.attempt_count + 1,
            processing_started_at: started_at,
            processed_at: nil,
            processing_error: nil
          )
          inbox_snapshot(message)
        end
      end

      def complete_command(command_id:, result:, processed_at: Time.current)
        Platform::InboxMessage.transaction do
          message = find_inbox_by_command!(command_id, lock: true)
          normalized_result = canonical_json(result)

          if message.status == "succeeded"
            unless canonical_json(message.result) == normalized_result
              raise IdempotencyConflict, "command already completed with a different result"
            end

            return inbox_snapshot(message)
          end

          message.update!(
            status: "succeeded",
            result: normalized_result,
            processing_error: nil,
            processed_at:
          )
          inbox_snapshot(message)
        end
      end

      def fail_command(command_id:, error:, processed_at: Time.current)
        Platform::InboxMessage.transaction do
          message = find_inbox_by_command!(command_id, lock: true)
          return inbox_snapshot(message) if message.status == "succeeded"

          message.update!(
            status: "failed",
            processing_error: canonical_json(error),
            processed_at:
          )
          inbox_snapshot(message)
        end
      end

      def fetch_command(command_id:)
        inbox_snapshot(find_inbox_by_command!(command_id))
      end

      def append_domain_event(
        event_type:,
        aggregate_type:,
        aggregate_id:,
        expected_aggregate_version:,
        data:,
        event_version: 1,
        occurred_at: Time.current,
        effective_at: nil,
        principal: nil,
        credential: nil,
        actor: nil,
        executor: nil,
        interface: nil,
        client: nil,
        evidence_references: [],
        correlation_id: nil,
        causation_id: nil,
        command_id: nil,
        idempotency_key: nil,
        outbox_messages: []
      )
        organization_id = current_organization_id!
        normalized_event = normalize_event_attributes(
          organization_id:,
          event_type:,
          event_version:,
          aggregate_type:,
          aggregate_id:,
          expected_aggregate_version:,
          occurred_at:,
          effective_at:,
          principal:,
          credential:,
          actor:,
          executor:,
          interface:,
          client:,
          evidence_references:,
          correlation_id:,
          causation_id:,
          command_id:,
          idempotency_key:,
          data:
        )
        normalized_outbox = normalize_outbox_messages(outbox_messages, default_available_at: occurred_at)

        Platform::DomainEvent.transaction do
          lock_aggregate!(
            organization_id:,
            aggregate_type: normalized_event.fetch(:aggregate_type),
            aggregate_id: normalized_event.fetch(:aggregate_id)
          )
          current_version = current_aggregate_version(
            organization_id:,
            aggregate_type: normalized_event.fetch(:aggregate_type),
            aggregate_id: normalized_event.fetch(:aggregate_id)
          )
          expected_version = normalized_event.delete(:expected_aggregate_version)

          unless current_version == expected_version
            raise ConcurrencyConflict,
              "expected aggregate version #{expected_version}, current version is #{current_version}"
          end

          event = Platform::DomainEvent.create!(
            **normalized_event,
            aggregate_version: current_version + 1
          )
          outbox = normalized_outbox.map do |message|
            Platform::OutboxMessage.create!(
              **message,
              organization_id:,
              domain_event_id: event.id
            )
          end

          deep_freeze(event: event_snapshot(event), outbox: outbox.map { outbox_snapshot(_1) })
        end
      end

      def claim_outbox(limit: 100, at: Time.current, lease_timeout: DEFAULT_OUTBOX_LEASE)
        unless limit.is_a?(Integer) && limit.positive?
          raise InvalidInput, "limit must be a positive integer"
        end
        unless lease_timeout.respond_to?(:positive?) && lease_timeout.positive?
          raise InvalidInput, "lease_timeout must be positive"
        end

        stale_before = at - lease_timeout

        Platform::OutboxMessage.transaction do
          messages = Platform::OutboxMessage
            .where(
              "(status IN (?) AND available_at <= ?) OR " \
                "(status = ? AND publishing_started_at IS NOT NULL AND publishing_started_at <= ?)",
              %w[pending failed],
              at,
              "publishing",
              stale_before
            )
            .order(:available_at, :created_at, :id)
            .limit(limit)
            .lock("FOR UPDATE SKIP LOCKED")
            .to_a

          messages.each do |message|
            message.update!(
              status: "publishing",
              attempt_count: message.attempt_count + 1,
              publishing_started_at: at,
              last_error: nil
            )
          end

          deep_freeze(messages.map { outbox_snapshot(_1) })
        end
      end

      def mark_outbox_published(message_id:, published_at: Time.current)
        Platform::OutboxMessage.transaction do
          message = find_outbox!(message_id, lock: true)
          message.update!(
            status: "published",
            publishing_started_at: nil,
            published_at:,
            last_error: nil
          )
          outbox_snapshot(message)
        end
      end

      def mark_outbox_failed(message_id:, error:, retry_at: Time.current)
        Platform::OutboxMessage.transaction do
          message = find_outbox!(message_id, lock: true)
          message.update!(
            status: "failed",
            available_at: retry_at,
            publishing_started_at: nil,
            last_error: canonical_json(error)
          )
          outbox_snapshot(message)
        end
      end

      def normalize_command_attributes(**attributes)
        payload = canonical_json(attributes.fetch(:payload))

        {
          organization_id: attributes.fetch(:organization_id),
          message_id: required_string(attributes.fetch(:message_id), :message_id),
          command_id: required_string(attributes.fetch(:command_id), :command_id),
          idempotency_key: required_string(attributes.fetch(:idempotency_key), :idempotency_key),
          command_name: required_string(attributes.fetch(:command_name), :command_name),
          command_version: positive_integer(attributes.fetch(:command_version), :command_version),
          interface: required_string(attributes.fetch(:interface), :interface),
          client: required_string(attributes.fetch(:client), :client),
          principal: required_string(attributes.fetch(:principal), :principal),
          credential: optional_string(attributes[:credential], :credential),
          actor: optional_string(attributes[:actor], :actor),
          executor: optional_string(attributes[:executor], :executor),
          correlation_id: optional_string(attributes[:correlation_id], :correlation_id),
          causation_id: optional_string(attributes[:causation_id], :causation_id),
          payload:,
          payload_digest: Digest::SHA256.hexdigest(JSON.generate(payload)),
          payload_reference: optional_string(attributes[:payload_reference], :payload_reference),
          status: "received",
          attempt_count: 0,
          received_at: attributes.fetch(:received_at)
        }
      end
      private_class_method :normalize_command_attributes

      def normalize_event_attributes(**attributes)
        evidence_references = attributes.fetch(:evidence_references)
        unless evidence_references.is_a?(Array)
          raise InvalidInput, "evidence_references must be an array"
        end

        expected_version = attributes.fetch(:expected_aggregate_version)
        unless expected_version.is_a?(Integer) && expected_version >= 0
          raise InvalidInput, "expected_aggregate_version must be a non-negative integer"
        end

        {
          organization_id: attributes.fetch(:organization_id),
          event_type: required_string(attributes.fetch(:event_type), :event_type),
          event_version: positive_integer(attributes.fetch(:event_version), :event_version),
          aggregate_type: required_string(attributes.fetch(:aggregate_type), :aggregate_type),
          aggregate_id: required_string(attributes.fetch(:aggregate_id), :aggregate_id),
          expected_aggregate_version: expected_version,
          occurred_at: attributes.fetch(:occurred_at),
          effective_at: attributes[:effective_at],
          principal: optional_string(attributes[:principal], :principal),
          credential: optional_string(attributes[:credential], :credential),
          actor: optional_string(attributes[:actor], :actor),
          executor: optional_string(attributes[:executor], :executor),
          interface: optional_string(attributes[:interface], :interface),
          client: optional_string(attributes[:client], :client),
          evidence_references: canonical_json(evidence_references),
          correlation_id: optional_string(attributes[:correlation_id], :correlation_id),
          causation_id: optional_string(attributes[:causation_id], :causation_id),
          command_id: optional_string(attributes[:command_id], :command_id),
          idempotency_key: optional_string(attributes[:idempotency_key], :idempotency_key),
          data: canonical_json(attributes.fetch(:data))
        }
      end
      private_class_method :normalize_event_attributes

      def normalize_outbox_messages(messages, default_available_at:)
        unless messages.is_a?(Array)
          raise InvalidInput, "outbox_messages must be an array"
        end

        messages.map do |message|
          unless message.is_a?(Hash)
            raise InvalidInput, "each outbox message must be an object"
          end

          attributes = message.symbolize_keys
          {
            message_type: required_string(attributes.fetch(:message_type), :message_type),
            message_version: positive_integer(attributes.fetch(:message_version, 1), :message_version),
            destination: optional_string(attributes[:destination], :destination),
            payload: canonical_json(attributes.fetch(:payload)),
            status: "pending",
            attempt_count: 0,
            available_at: attributes.fetch(:available_at, default_available_at)
          }
        rescue KeyError => error
          raise InvalidInput, "missing outbox field: #{error.key}"
        end
      end
      private_class_method :normalize_outbox_messages

      def duplicate_inbox_message(attributes)
        Platform::InboxMessage.find_by(command_id: attributes.fetch(:command_id)) ||
          Platform::InboxMessage.find_by(idempotency_key: attributes.fetch(:idempotency_key)) ||
          Platform::InboxMessage.find_by(message_id: attributes.fetch(:message_id)) ||
          raise(IdempotencyConflict, "inbox uniqueness conflict could not be resolved")
      end
      private_class_method :duplicate_inbox_message

      def verify_idempotent_duplicate!(message, attributes)
        matches = message.command_id == attributes.fetch(:command_id) &&
          message.idempotency_key == attributes.fetch(:idempotency_key) &&
          message.command_name == attributes.fetch(:command_name) &&
          message.command_version == attributes.fetch(:command_version) &&
          message.payload_digest == attributes.fetch(:payload_digest)
        return if matches

        raise IdempotencyConflict, "command identity or payload conflicts with an existing inbox message"
      end
      private_class_method :verify_idempotent_duplicate!

      def find_inbox_by_command!(command_id, lock: false)
        relation = Platform::InboxMessage.where(command_id: required_string(command_id, :command_id))
        relation = relation.lock if lock
        relation.first!
      rescue ActiveRecord::RecordNotFound
        raise NotFound, "command not found"
      end
      private_class_method :find_inbox_by_command!

      def find_outbox!(message_id, lock: false)
        uuid = typed_uuid(message_id, "outbox")
        relation = Platform::OutboxMessage.where(id: uuid)
        relation = relation.lock if lock
        relation.first!
      rescue ActiveRecord::RecordNotFound
        raise NotFound, "outbox message not found"
      end
      private_class_method :find_outbox!

      def lock_aggregate!(organization_id:, aggregate_type:, aggregate_id:)
        key = [ organization_id, aggregate_type, aggregate_id ].join(":")
        connection = Platform::DomainEvent.connection
        connection.execute(
          "SELECT pg_advisory_xact_lock(hashtextextended(#{connection.quote(key)}, 0))"
        )
      end
      private_class_method :lock_aggregate!

      def current_aggregate_version(organization_id:, aggregate_type:, aggregate_id:)
        Platform::DomainEvent
          .where(organization_id:, aggregate_type:, aggregate_id:)
          .maximum(:aggregate_version)
          .to_i
      end
      private_class_method :current_aggregate_version

      def current_organization_id!
        value = ActiveRecord::Base.connection.select_value(
          "SELECT current_setting('app.current_organization', true)"
        )
        raise MissingWorkspace, "workspace database scope is required" if value.blank?

        value
      end
      private_class_method :current_organization_id!

      def inbox_snapshot(message)
        deep_freeze(
          id: typed_id("inbox", message.id),
          workspace_id: typed_id("org", message.organization_id),
          message_id: message.message_id,
          command_id: message.command_id,
          idempotency_key: message.idempotency_key,
          command_name: message.command_name,
          command_version: message.command_version,
          interface: message.interface,
          client: message.client,
          principal: message.principal,
          credential: message.credential,
          actor: message.actor,
          executor: message.executor,
          correlation_id: message.correlation_id,
          causation_id: message.causation_id,
          payload_digest: message.payload_digest,
          payload_reference: message.payload_reference,
          status: message.status,
          attempt_count: message.attempt_count,
          result: message.result&.deep_dup,
          processing_error: message.processing_error&.deep_dup,
          received_at: message.received_at,
          processing_started_at: message.processing_started_at,
          processed_at: message.processed_at
        )
      end
      private_class_method :inbox_snapshot

      def event_snapshot(event)
        deep_freeze(
          id: typed_id("event", event.id),
          workspace_id: typed_id("org", event.organization_id),
          event_type: event.event_type,
          event_version: event.event_version,
          aggregate_type: event.aggregate_type,
          aggregate_id: event.aggregate_id,
          aggregate_version: event.aggregate_version,
          occurred_at: event.occurred_at,
          effective_at: event.effective_at,
          principal: event.principal,
          credential: event.credential,
          actor: event.actor,
          executor: event.executor,
          interface: event.interface,
          client: event.client,
          evidence_references: event.evidence_references.deep_dup,
          correlation_id: event.correlation_id,
          causation_id: event.causation_id,
          command_id: event.command_id,
          idempotency_key: event.idempotency_key,
          data: event.data.deep_dup
        )
      end
      private_class_method :event_snapshot

      def outbox_snapshot(message)
        deep_freeze(
          id: typed_id("outbox", message.id),
          workspace_id: typed_id("org", message.organization_id),
          domain_event_id: typed_id("event", message.domain_event_id),
          message_type: message.message_type,
          message_version: message.message_version,
          destination: message.destination,
          payload: message.payload.deep_dup,
          status: message.status,
          attempt_count: message.attempt_count,
          available_at: message.available_at,
          publishing_started_at: message.publishing_started_at,
          published_at: message.published_at,
          last_error: message.last_error&.deep_dup
        )
      end
      private_class_method :outbox_snapshot

      def required_string(value, field)
        return value.dup if value.is_a?(String) && value.strip.present?

        raise InvalidInput, "#{field} must be a non-empty string"
      end
      private_class_method :required_string

      def optional_string(value, field)
        return if value.nil?
        return value.dup if value.is_a?(String) && value.strip.present?

        raise InvalidInput, "#{field} must be omitted or a non-empty string"
      end
      private_class_method :optional_string

      def positive_integer(value, field)
        return value if value.is_a?(Integer) && value.positive?

        raise InvalidInput, "#{field} must be a positive integer"
      end
      private_class_method :positive_integer

      def typed_id(prefix, uuid)
        TypeID.from_uuid(prefix, uuid).to_s
      end
      private_class_method :typed_id

      def typed_uuid(value, prefix)
        typed = TypeID.from_string(required_string(value, :id))
        raise InvalidInput, "id must use the #{prefix} prefix" unless typed.prefix == prefix

        typed.uuid.to_s
      rescue TypeID::Error
        raise InvalidInput, "id must be a valid #{prefix} typed identifier"
      end
      private_class_method :typed_uuid

      def canonical_json(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested), normalized|
            normalized[key.to_s] = canonical_json(nested)
          end.sort.to_h
        when Array
          value.map { canonical_json(_1) }
        when String
          value.dup
        when Numeric, TrueClass, FalseClass, NilClass
          value
        when Time, Date, DateTime, ActiveSupport::TimeWithZone
          value.iso8601
        else
          raise InvalidInput, "value is not JSON-compatible: #{value.class}"
        end
      end
      private_class_method :canonical_json

      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, nested| key.freeze; deep_freeze(nested) }
        when Array
          value.each { deep_freeze(_1) }
        when String
          value.freeze
        end
        value.freeze
      end
      private_class_method :deep_freeze
    end
  end
end
