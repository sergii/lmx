# frozen_string_literal: true

require "json"
require "net/http"

module Delivery
  module Telegram
    class Client
      class Error < StandardError; end

      API_BASE = "https://api.telegram.org"

      def initialize(token:, chat_id:, api_base: API_BASE)
        @token = token.to_s
        @chat_id = chat_id.to_s
        @api_base = api_base.to_s
      end

      def send_message(text:)
        uri = URI("#{api_base}/bot#{token}/sendMessage")
        response = Net::HTTP.post(
          uri,
          JSON.generate(chat_id:, text:),
          "Content-Type" => "application/json"
        )
        return true if response.is_a?(Net::HTTPSuccess)

        raise Error, "Telegram sendMessage failed with HTTP #{response.code}"
      end

      def probe!
        get!("getMe")
        get!("getChat", chat_id:)
        true
      end

      private

      attr_reader :token, :chat_id, :api_base

      def get!(method_name, params = {})
        uri = URI("#{api_base}/bot#{token}/#{method_name}")
        uri.query = URI.encode_www_form(params) if params.any?
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 3
        http.read_timeout = 5
        response = http.get(uri.request_uri)
        raise Error, "Telegram #{method_name} failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        payload = JSON.parse(response.body)
        raise Error, "Telegram #{method_name} returned an unsuccessful response" unless payload["ok"] == true

        payload
      rescue JSON::ParserError
        raise Error, "Telegram #{method_name} returned invalid JSON"
      end
    end
  end
end
