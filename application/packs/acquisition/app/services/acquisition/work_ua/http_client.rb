# frozen_string_literal: true

require "net/http"
require "uri"

module Acquisition
  module WorkUa
    class HttpClient
      Response = Data.define(:body, :status, :content_type, :url, :fetched_at)

      class HttpError < StandardError
        attr_reader :status, :url

        def initialize(status:, url:)
          @status = status
          @url = url
          super("Work.ua HTTP request failed with status #{status} for #{url}")
        end
      end

      MAX_REDIRECTS = 3
      ACCEPT = "text/html,application/xhtml+xml;q=0.9,*/*;q=0.1"

      def initialize(open_timeout: 5, read_timeout: 15, user_agent: "LMX Acquisition/1.0")
        @open_timeout = open_timeout
        @read_timeout = read_timeout
        @user_agent = user_agent
      end

      def get(url)
        request(URI.parse(url), redirects_remaining: MAX_REDIRECTS)
      end

      private

      attr_reader :open_timeout, :read_timeout, :user_agent

      def request(uri, redirects_remaining:)
        response = perform_request(uri)

        if response.is_a?(Net::HTTPRedirection)
          return follow_redirect(uri, response, redirects_remaining:)
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise HttpError.new(status: response.code.to_i, url: uri.to_s)
        end

        Response.new(
          body: response.body.to_s,
          status: response.code.to_i,
          content_type: response["content-type"].to_s.presence || "text/html",
          url: uri.to_s,
          fetched_at: Time.current
        )
      end

      def perform_request(uri)
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = ACCEPT
        request["User-Agent"] = user_agent

        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout:,
          read_timeout:
        ) { _1.request(request) }
      end

      def follow_redirect(uri, response, redirects_remaining:)
        raise HttpError.new(status: response.code.to_i, url: uri.to_s) if redirects_remaining <= 0

        location = response["location"].to_s
        redirected = URI.join(uri.to_s, location)
        unless redirected.host == uri.host && redirected.scheme.in?(%w[http https])
          raise HttpError.new(status: response.code.to_i, url: redirected.to_s)
        end

        request(redirected, redirects_remaining: redirects_remaining - 1)
      rescue URI::InvalidURIError
        raise HttpError.new(status: response.code.to_i, url: uri.to_s)
      end
    end
  end
end
