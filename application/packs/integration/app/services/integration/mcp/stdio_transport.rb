# frozen_string_literal: true

require "json"

module Integration
  module Mcp
    class StdioTransport
      DEFAULT_MAX_LINE_BYTES = 4 * 1024 * 1024

      def initialize(server:, input: $stdin, output: $stdout, error: $stderr, max_line_bytes: DEFAULT_MAX_LINE_BYTES)
        @server = server
        @input = input
        @output = output
        @error = error
        @max_line_bytes = Integer(max_line_bytes)
      end

      def open
        output.sync = true if output.respond_to?(:sync=)

        while (line = input.gets)
          next if line.strip.empty?

          if line.bytesize > max_line_bytes
            write_error(Server::INVALID_REQUEST, "MCP frame exceeds #{max_line_bytes} bytes")
            break
          end

          handle_line(line)
        end
      end

      private

      attr_reader :server, :input, :output, :error, :max_line_bytes

      def handle_line(line)
        message = JSON.parse(line)
        response = server.call(message)
        write(response) if response
      rescue JSON::ParserError
        write_error(Server::PARSE_ERROR, "Parse error")
      rescue StandardError => exception
        error.puts("LMX MCP stdio error: #{exception.class}: #{exception.message}")
        write_error(Server::INTERNAL_ERROR, "Internal error")
      end

      def write_error(code, message)
        write(
          "jsonrpc" => "2.0",
          "id" => nil,
          "error" => { "code" => code, "message" => message }
        )
      end

      def write(payload)
        output.write(JSON.generate(payload))
        output.write("\n")
        output.flush if output.respond_to?(:flush)
      end
    end
  end
end
