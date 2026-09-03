# frozen_string_literal: true

module Integration
  module Command
    class Dispatcher
      def initialize(command_port:, authorization_port:, workspace_scope:, reliability_api:, command_executor:)
        @command_port = command_port
        @authorization_port = authorization_port
        @workspace_scope = workspace_scope
        @reliability_api = reliability_api
        @command_executor = command_executor
      end

      def call(name:, version: 1, context:, input: {})
        contract = Contracts.fetch(name, version)
        command = Command.new(contract:, context:, input:)

        authorized = @authorization_port.authorize(command)
        raise Error::Unauthorized unless authorized

        @workspace_scope.call(context) { execute(command) }
      rescue Error => error
        failure_outcome(name:, version:, context:, contract: defined?(contract) ? contract : nil, error:)
      rescue Platform::Reliability::Api::IdempotencyConflict => error
        failure_outcome(
          name:, version:, context:, contract: defined?(contract) ? contract : nil,
          error: Error::IdempotencyConflict.new(error.message)
        )
      rescue Platform::Reliability::Api::ConcurrencyConflict => error
        failure_outcome(
          name:, version:, context:, contract: defined?(contract) ? contract : nil,
          error: Error::ConcurrencyConflict.new(error.message)
        )
      rescue Platform::Reliability::Api::InvalidInput => error
        failure_outcome(
          name:, version:, context:, contract: defined?(contract) ? contract : nil,
          error: Error::InvalidInput.new(error.message)
        )
      end

      private

      def execute(command)
        context = command.context
        receipt = @reliability_api.receive_command(
          message_id: context.message_id,
          command_id: context.command_id,
          idempotency_key: context.idempotency_key,
          command_name: command.contract.name,
          command_version: command.contract.version,
          interface: context.interface,
          client: context.client,
          principal: context.principal,
          credential: context.credential,
          actor: context.actor,
          executor: context.executor,
          correlation_id: context.correlation_id,
          causation_id: context.causation_id,
          payload: command.input
        )

        execution = @command_executor.call(command_id: context.command_id) do
          result = @command_port.call(command)
          unless result.is_a?(Ports::Result)
            raise Error::ContractViolation.new(
              "Command port must return Integration::Command::Ports::Result",
              details: { contract: command.contract.identifier }
            )
          end

          { data: result.data, provenance: result.provenance }
        end

        envelope = normalize_execution_result(execution.fetch(:result), command.contract)
        data = command.contract.normalize_output(envelope.fetch(:data))
        provenance = normalize_hash(envelope.fetch(:provenance), command.contract)
        inbox = receipt.fetch(:command)

        Outcome.success(
          contract: command.contract.reference,
          context:,
          data:,
          provenance:,
          command_meta: {
            inbox_id: inbox.fetch(:id),
            command_id: context.command_id,
            idempotency_key: context.idempotency_key,
            replayed: execution.fetch(:replayed)
          }.freeze
        )
      end

      def normalize_execution_result(value, contract)
        attributes = normalize_hash(value, contract)
        data = attributes[:data]
        provenance = attributes[:provenance]
        unless data.is_a?(Hash) && provenance.is_a?(Hash)
          raise Error::ContractViolation.new(
            "Stored command result envelope is invalid",
            details: { contract: contract.identifier }
          )
        end

        { data:, provenance: }.freeze
      end

      def normalize_hash(value, contract)
        unless value.is_a?(Hash)
          raise Error::ContractViolation.new(
            "Stored command result must be an object",
            details: { contract: contract.identifier }
          )
        end

        value.each_with_object({}) { |(key, item), normalized| normalized[key.to_sym] = item }
      end

      def failure_outcome(name:, version:, context:, contract:, error:)
        Outcome.failure(
          contract: contract_reference(name, version, contract),
          context: context.is_a?(Context) ? context : nil,
          error:
        )
      end

      def contract_reference(name, version, contract)
        return contract.reference if contract

        { name: name.to_s, version: }
      end
    end
  end
end
