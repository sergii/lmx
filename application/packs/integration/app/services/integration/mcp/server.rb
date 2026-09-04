# frozen_string_literal: true

module Integration
  module Mcp
    class Server
      MODERN_PROTOCOL_VERSION = "2026-07-28"
      LEGACY_PROTOCOL_VERSIONS = %w[2025-11-25 2025-06-18 2025-03-26].freeze
      SERVER_NAME = "lmx"
      SERVER_VERSION = "phase0"
      SERVER_INFO_META_KEY = "io.modelcontextprotocol/serverInfo"
      PROTOCOL_VERSION_META_KEY = "io.modelcontextprotocol/protocolVersion"
      CLIENT_CAPABILITIES_META_KEY = "io.modelcontextprotocol/clientCapabilities"
      IDEMPOTENCY_KEY_META_KEY = "com.lmx/idempotencyKey"

      PARSE_ERROR = -32_700
      INVALID_REQUEST = -32_600
      METHOD_NOT_FOUND = -32_601
      INVALID_PARAMS = -32_602
      INTERNAL_ERROR = -32_603
      UNSUPPORTED_PROTOCOL_VERSION = -32_022

      def initialize(read_adapter:, command_adapter:, identity:, server_name: SERVER_NAME, server_version: SERVER_VERSION)
        @read_adapter = read_adapter
        @command_adapter = command_adapter
        @identity = identity
        @server_name = server_name.to_s.freeze
        @server_version = server_version.to_s.freeze
        @era = nil
        @legacy_initialized = false
      end

      def call(message)
        unless message.is_a?(Hash)
          return error_response(nil, INVALID_REQUEST, "Request must be a JSON object")
        end

        request = stringify_keys(message)
        return error_response(request["id"], INVALID_REQUEST, "jsonrpc must be 2.0") unless request["jsonrpc"] == "2.0"

        method = request["method"]
        return error_response(request["id"], INVALID_REQUEST, "method must be a string") unless method.is_a?(String)

        return handle_notification(request) unless request.key?("id")

        case method
        when "server/discover"
          lock_era!(:modern)
          success_response(request.fetch("id"), discover_result, modern: true)
        when "initialize"
          handle_initialize(request)
        when "ping"
          handle_ping(request)
        when "tools/list"
          handle_tools_list(request)
        when "tools/call"
          handle_tools_call(request)
        else
          error_response(request.fetch("id"), METHOD_NOT_FOUND, "Method not found")
        end
      rescue EraConflict => error
        error_response(request_id(message), INVALID_REQUEST, error.message)
      rescue UnsupportedProtocolVersion => error
        error_response(
          request_id(message),
          UNSUPPORTED_PROTOCOL_VERSION,
          "Unsupported protocol version",
          supported: [ MODERN_PROTOCOL_VERSION ],
          requested: error.requested
        )
      rescue ArgumentError, KeyError => error
        error_response(request_id(message), INVALID_PARAMS, error.message)
      rescue StandardError
        error_response(request_id(message), INTERNAL_ERROR, "Internal error")
      end

      private

      class EraConflict < StandardError; end

      class UnsupportedProtocolVersion < StandardError
        attr_reader :requested

        def initialize(requested)
          @requested = requested
          super("unsupported protocol version: #{requested}")
        end
      end

      attr_reader :read_adapter, :command_adapter, :identity, :server_name, :server_version

      def handle_notification(request)
        return nil unless request.fetch("method") == "notifications/initialized"
        return nil if @era == :modern

        lock_era!(:legacy)
        @legacy_initialized = true
        nil
      end

      def handle_initialize(request)
        lock_era!(:legacy)
        params = object_params(request)
        requested = params.fetch("protocolVersion").to_s
        negotiated = LEGACY_PROTOCOL_VERSIONS.include?(requested) ? requested : LEGACY_PROTOCOL_VERSIONS.first
        @legacy_initialized = false

        success_response(
          request.fetch("id"),
          {
            "protocolVersion" => negotiated,
            "capabilities" => { "tools" => { "listChanged" => false } },
            "serverInfo" => server_info,
            "instructions" => instructions
          },
          modern: false
        )
      end

      def handle_ping(request)
        modern = modern_request?(request)
        if modern
          lock_era!(:modern)
          validate_modern_request!(request)
        elsif @era == :modern
          raise EraConflict, "MCP connection is already locked to modern lifecycle"
        end

        success_response(request.fetch("id"), {}, modern:)
      end

      def handle_tools_list(request)
        modern = modern_request?(request)
        lock_era!(modern ? :modern : :legacy)
        validate_modern_request!(request) if modern
        ensure_legacy_ready! unless modern

        result = { "tools" => all_tools }
        if modern
          result["ttlMs"] = 0
          result["cacheScope"] = "private"
        end

        success_response(request.fetch("id"), result, modern:)
      end

      def handle_tools_call(request)
        modern = modern_request?(request)
        lock_era!(modern ? :modern : :legacy)
        validate_modern_request!(request) if modern
        ensure_legacy_ready! unless modern

        params = object_params(request)
        name = params.fetch("name").to_s
        raise ArgumentError, "tool name must be present" if name.strip.empty?

        arguments = params.fetch("arguments", {})
        raise ArgumentError, "tool arguments must be an object" unless arguments.is_a?(Hash)

        meta = params.fetch("_meta", {})
        raise ArgumentError, "_meta must be an object" unless meta.is_a?(Hash)

        adapter, context = adapter_and_context(
          name:,
          request_id: request.fetch("id"),
          idempotency_key: meta[IDEMPOTENCY_KEY_META_KEY]
        )
        raise ArgumentError, "unknown MCP tool: #{name}" unless adapter

        result = stringify_keys(adapter.call(name:, arguments:, context:))
        success_response(request.fetch("id"), result, modern:)
      end

      def adapter_and_context(name:, request_id:, idempotency_key: nil)
        if read_tool_names.include?(name)
          [ read_adapter, identity.read_context(request_id:) ]
        elsif command_tool_names.include?(name)
          [
            command_adapter,
            identity.command_context(request_id:, tool_name: name, idempotency_key:)
          ]
        end
      end

      def all_tools
        (read_adapter.tools + command_adapter.tools)
          .map { stringify_keys(_1) }
          .sort_by { _1.fetch("name") }
      end

      def read_tool_names
        @read_tool_names ||= read_adapter.tools.map { tool_name(_1) }.freeze
      end

      def command_tool_names
        @command_tool_names ||= command_adapter.tools.map { tool_name(_1) }.freeze
      end

      def tool_name(tool)
        value = tool[:name] || tool["name"]
        value.to_s
      end

      def discover_result
        {
          "supportedVersions" => [ MODERN_PROTOCOL_VERSION ],
          "capabilities" => { "tools" => {} },
          "instructions" => instructions,
          "ttlMs" => 0,
          "cacheScope" => "private"
        }
      end

      def instructions
        "LMX exposes workspace-authorized market, candidate, assessment, and workflow tools. Write tools are capability-gated and idempotent."
      end

      def modern_request?(request)
        meta = request.dig("params", "_meta")
        meta.is_a?(Hash) && meta.key?(PROTOCOL_VERSION_META_KEY)
      end

      def validate_modern_request!(request)
        meta = object_params(request).fetch("_meta")
        raise ArgumentError, "_meta must be an object" unless meta.is_a?(Hash)

        requested = meta.fetch(PROTOCOL_VERSION_META_KEY).to_s
        raise UnsupportedProtocolVersion, requested unless requested == MODERN_PROTOCOL_VERSION

        capabilities = meta.fetch(CLIENT_CAPABILITIES_META_KEY)
        raise ArgumentError, "client capabilities must be an object" unless capabilities.is_a?(Hash)
      end

      def ensure_legacy_ready!
        raise EraConflict, "MCP legacy connection is not initialized" unless @legacy_initialized
      end

      def lock_era!(requested)
        if @era && @era != requested
          raise EraConflict, "MCP connection is already locked to #{@era} lifecycle"
        end

        @era ||= requested
      end

      def success_response(id, result, modern:)
        payload = stringify_keys(result)
        if modern
          payload = payload.merge(
            "resultType" => payload.fetch("resultType", "complete"),
            "_meta" => stringify_keys(payload.fetch("_meta", {})).merge(SERVER_INFO_META_KEY => server_info)
          )
        end

        {
          "jsonrpc" => "2.0",
          "id" => id,
          "result" => payload
        }
      end

      def error_response(id, code, message, data = nil)
        error = { "code" => code, "message" => message }
        error["data"] = stringify_keys(data) if data

        {
          "jsonrpc" => "2.0",
          "id" => id,
          "error" => error
        }
      end

      def server_info
        { "name" => server_name, "version" => server_version }
      end

      def object_params(request)
        params = request.fetch("params", {})
        raise ArgumentError, "params must be an object" unless params.is_a?(Hash)

        stringify_keys(params)
      end

      def request_id(message)
        return unless message.is_a?(Hash)

        message["id"] || message[:id]
      end

      def stringify_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested), result|
            result[key.to_s] = stringify_keys(nested)
          end
        when Array
          value.map { stringify_keys(_1) }
        else
          value
        end
      end
    end
  end
end
