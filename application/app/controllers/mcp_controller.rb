# frozen_string_literal: true

class McpController < ActionController::API
  def create
    transport = Integration::McpHttpRuntime.build(
      token: bearer_token!,
      environment: ENV
    )
    status, response_headers, body = transport.call(request)

    response_headers.each { |name, value| response.set_header(name, value) }
    self.status = status
    self.response_body = body
  rescue Integration::McpHttpRuntime::Unauthenticated
    unauthorized
  rescue Integration::McpHttpRuntime::AuthenticationUnavailable
    render json: { error: "mcp_oauth_unavailable" }, status: :service_unavailable
  rescue Integration::McpHttpRuntime::ConfigurationError
    render json: { error: "mcp_http_unavailable" }, status: :service_unavailable
  end

  def oauth_protected_resource_metadata
    metadata = Integration::McpOauthResourceMetadata.build(environment: ENV)
    response.set_header("Cache-Control", "public, max-age=300")
    render json: metadata.to_h
  rescue Integration::McpOauthResourceMetadata::NotConfigured
    head :not_found
  rescue Integration::McpOauthResourceMetadata::ConfigurationError
    render json: { error: "mcp_oauth_metadata_unavailable" }, status: :service_unavailable
  end

  private

  def bearer_token!
    authorization = request.get_header("HTTP_AUTHORIZATION").to_s
    match = /\ABearer\s+([^\s]+)\z/i.match(authorization)
    raise Integration::McpHttpRuntime::Unauthenticated unless match

    match[1]
  end

  def unauthorized
    challenge = Integration::McpOauthResourceMetadata.challenge(environment: ENV)
    response.set_header("WWW-Authenticate", challenge)
    render json: { error: "unauthorized" }, status: :unauthorized
  rescue Integration::McpOauthResourceMetadata::ConfigurationError
    render json: { error: "mcp_oauth_metadata_unavailable" }, status: :service_unavailable
  end
end
