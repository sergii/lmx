# frozen_string_literal: true

require "json"
require "uri"

module Integration
  module Mcp
    class HttpTransport
      MAX_BODY_BYTES = 4 * 1024 * 1024
      JSON_CONTENT_TYPE = "application/json"
      BAD_REQUEST_CODES = [
        Server::HEADER_MISMATCH,
        Server::UNSUPPORTED_PROTOCOL_VERSION,
        Server::PARSE_ERROR,
        Server::INVALID_REQUEST,
        Server::INVALID_PARAMS
      ].freeze

      def initialize(server:, allowed_hosts:, allowed_origins: [], max_body_bytes: MAX_BODY_BYTES)
        @server = server
        @allowed_hosts = normalize_hosts(allowed_hosts)
        @allowed_origins = normalize_origins(allowed_origins)
        @max_body_bytes = Integer(max_body_bytes)

        raise ArgumentError, "allowed_hosts must not be empty" if @allowed_hosts.empty?
        raise ArgumentError, "max_body_bytes must be positive" unless @max_body_bytes.positive?
      end

      def call(request)
        return plain_response(405, "method_not_allowed", allow: "POST") unless request.post?
        return plain_response(403, "forbidden_host") unless host_allowed?(request)
        return plain_response(403, "forbidden_origin") unless origin_allowed?(request)
        return plain_response(415, "unsupported_media_type") unless request.media_type == JSON_CONTENT_TYPE

        raw = request.body.read(max_body_bytes + 1).to_s
        return plain_response(413, "payload_too_large") if raw.bytesize > max_body_bytes

        message = JSON.parse(raw)
        header_error = validate_standard_headers(request, message)
        return json_rpc_response(400, header_error) if header_error

        result = server.call(message)
        return [ 202, no_store_headers, "" ] if result.nil?

        status = bad_request?(result) ? 400 : 200
        json_rpc_response(status, result)
      rescue JSON::ParserError
        json_rpc_response(
          400,
          rpc_error(nil, Server::PARSE_ERROR, "Parse error")
        )
      end

      private

      attr_reader :server, :allowed_hosts, :allowed_origins, :max_body_bytes

      def validate_standard_headers(request, message)
        return unless message.is_a?(Hash) && (message.key?("id") || message.key?(:id))

        body = stringify_keys(message)
        request_id = body["id"]
        protocol_version = header(request, "HTTP_MCP_PROTOCOL_VERSION")
        method = header(request, "HTTP_MCP_METHOD")

        return header_mismatch(request_id, "MCP-Protocol-Version", Server::MODERN_PROTOCOL_VERSION, nil) if protocol_version.empty?
        unless protocol_version == Server::MODERN_PROTOCOL_VERSION
          return rpc_error(
            request_id,
            Server::UNSUPPORTED_PROTOCOL_VERSION,
            "Unsupported protocol version",
            supported: [ Server::MODERN_PROTOCOL_VERSION ],
            requested: protocol_version
          )
        end

        body_version = body.dig("params", "_meta", Server::PROTOCOL_VERSION_META_KEY)
        unless body_version.to_s == protocol_version
          return header_mismatch(request_id, "MCP-Protocol-Version", body_version, protocol_version)
        end

        body_method = body["method"]
        return header_mismatch(request_id, "Mcp-Method", body_method, nil) if method.empty?
        return header_mismatch(request_id, "Mcp-Method", body_method, method) unless method == body_method

        return unless body_method == "tools/call"

        name = header(request, "HTTP_MCP_NAME")
        body_name = body.dig("params", "name")
        return header_mismatch(request_id, "Mcp-Name", body_name, nil) if name.empty?
        return header_mismatch(request_id, "Mcp-Name", body_name, name) unless name == body_name

        nil
      end

      def header_mismatch(request_id, header_name, expected, actual)
        rpc_error(
          request_id,
          Server::HEADER_MISMATCH,
          "MCP HTTP header mismatch",
          header: header_name,
          expected:,
          actual:
        )
      end

      def bad_request?(payload)
        code = payload.dig("error", "code")
        BAD_REQUEST_CODES.include?(code)
      end

      def host_allowed?(request)
        candidates = [ request.host.to_s.downcase, request.host_with_port.to_s.downcase ]
        candidates.any? { allowed_hosts.include?(_1) }
      end

      def origin_allowed?(request)
        raw = request.get_header("HTTP_ORIGIN").to_s.strip
        return true if raw.empty?

        origin = normalize_origin(raw)
        origin && allowed_origins.include?(origin)
      end

      def normalize_hosts(values)
        Array(values).filter_map do |value|
          host = value.to_s.strip.downcase
          next if host.empty?
          raise ArgumentError, "wildcard MCP HTTP hosts are not allowed" if host == "*"

          host
        end.uniq.freeze
      end

      def normalize_origins(values)
        Array(values).filter_map do |value|
          raw = value.to_s.strip
          next if raw.empty?
          raise ArgumentError, "wildcard MCP HTTP origins are not allowed" if raw == "*"

          normalize_origin(raw) || raise(ArgumentError, "invalid MCP HTTP origin: #{raw}")
        end.uniq.freeze
      end

      def normalize_origin(value)
        uri = URI.parse(value)
        return unless %w[http https].include?(uri.scheme&.downcase)
        return unless uri.host
        return unless uri.userinfo.nil?
        return unless uri.query.nil? && uri.fragment.nil?
        return unless uri.path.empty? || uri.path == "/"

        scheme = uri.scheme.downcase
        host = uri.host.downcase
        port = uri.port
        default_port = scheme == "https" ? 443 : 80
        suffix = port == default_port ? "" : ":#{port}"
        "#{scheme}://#{host}#{suffix}"
      rescue URI::InvalidURIError
        nil
      end

      def header(request, rack_name)
        request.get_header(rack_name).to_s.strip
      end

      def json_rpc_response(status, payload)
        [ status, no_store_headers.merge("Content-Type" => JSON_CONTENT_TYPE), JSON.generate(payload) ]
      end

      def plain_response(status, code, allow: nil)
        headers = no_store_headers.merge("Content-Type" => JSON_CONTENT_TYPE)
        headers["Allow"] = allow if allow
        [ status, headers, JSON.generate(error: code) ]
      end

      def no_store_headers
        { "Cache-Control" => "no-store" }
      end

      def rpc_error(id, code, message, data = nil)
        error = { "code" => code, "message" => message }
        error["data"] = stringify_keys(data) if data

        {
          "jsonrpc" => "2.0",
          "id" => id,
          "error" => error
        }
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
