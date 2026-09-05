# OpenAI and ChatGPT MCP compatibility

LMX exposes one authenticated MCP resource at `POST /mcp`. The HTTP boundary intentionally accepts both the current LMX-native MCP `2026-07-28` envelope and the 2025-era Streamable HTTP lifecycle still used by deployed OpenAI hosted MCP clients.

This document is an interoperability guide, not a second protocol implementation. Both eras enter the same authenticated `Integration::Mcp::Server`, read stack, command stack, workspace authorization, and transactional command path.

## Wire compatibility

A 2025-era hosted client may use separate HTTP requests for:

```text
initialize
  -> notifications/initialized
  -> tools/list
  -> tools/call
```

LMX does not mint `Mcp-Session-Id` for that flow. The HTTP runtime is deliberately stateless, so each request can be served by a fresh Rails process while the stdio runtime keeps its existing stateful legacy initialization boundary.

For legacy requests:

- `initialize` may arrive without `MCP-Protocol-Version`.
- later requests may send `MCP-Protocol-Version: 2025-11-25`, `2025-06-18`, or `2025-03-26`.
- a legacy request without the header uses the `2025-03-26` compatibility baseline.
- `Mcp-Method` and `Mcp-Name` are not required because they belong to the newer 2026 envelope.
- arbitrary legacy `_meta` values such as progress or tracing signals do not make a request a 2026 request.

For MCP `2026-07-28`, LMX remains strict. Requests and notifications must carry the protocol header plus `Mcp-Method`, and `tools/call` must also carry `Mcp-Name`. The protocol version in the body `_meta` must agree with the HTTP header.

## Tool annotations

LMX publishes MCP ToolAnnotations so a host can make better approval and presentation decisions.

Read tools advertise:

```json
{
  "readOnlyHint": true,
  "destructiveHint": false,
  "openWorldHint": false
}
```

Current write tools are additive rather than destructive, so they advertise `readOnlyHint: false`, `destructiveHint: false`, and `openWorldHint: false`.

Remote HTTP write tools additionally advertise `idempotentHint: true` because LMX requires a stable `idempotencyKey` as part of the tool input. The same intended write must reuse the same key on retry; a distinct intended write must use a new key.

The `idempotencyKey` field is transport metadata. `Integration::Mcp::Server` removes it before the versioned domain command contract sees the arguments. Existing clients may continue to send `com.lmx/idempotencyKey` in MCP `_meta`; if both forms are present they must match.

## Authentication and local pairing

OpenAI remains the MCP client. LMX remains the OAuth protected resource.

The normal remote path is:

```text
OpenAI / ChatGPT
  -> OAuth access token
  -> LMX RFC 7662 verification
  -> persisted local OAuth grant
  -> Workspace capability intersection
  -> MCP tool execution
```

LMX also has a first-contact pairing flow for a verified external identity that has no local mapping. It returns `403 mcp_pairing_required` with a short-lived browser pairing URL. That response is an LMX onboarding extension, not a standard MCP redirect contract, so production OpenAI setup should not assume every host will automatically open it. Complete the local pairing once through the LMX browser/admin flow, then retry the MCP connection with the same external identity.

Revoked or blocked identities are never eligible for first-contact pairing again. They remain known and fail closed.

## OpenAI hosted MCP smoke test

A hosted OpenAI MCP configuration needs the public LMX server URL and an access token issued for the configured LMX OAuth resource. Conceptually the tool configuration is:

```json
{
  "type": "mcp",
  "server_label": "lmx",
  "server_url": "https://lmx.example.com/mcp",
  "authorization": "<oauth-access-token>"
}
```

The exact OpenAI product surface may add approval policy, allowed-tool filtering, or interactive OAuth setup. Those are client controls and do not change LMX authorization.

Before a live smoke test, verify:

1. `LMX_MCP_HTTP_ALLOWED_HOSTS` contains the public LMX host.
2. RFC 9728 metadata points at that exact `https://.../mcp` resource.
3. the configured external authorization server can introspect the access token.
4. the external `(issuer, subject, client_id)` identity has an active local LMX grant, or an administrator completes first-contact pairing.
5. the grant and current Workspace role expose the capabilities the client is expected to see.

Then verify the client can list tools and call `openings.search`. For a write smoke test, let the model provide a fresh `idempotencyKey`, call an additive write tool once, and retry the exact same call with the same key to prove the command is not applied twice.

## Interoperability regression contract

`spec/requests/mcp_openai_compat_spec.rb` reproduces the deployed hosted-client shape without requiring a live OpenAI account or secret. It intentionally uses `clientInfo.name = openai-mcp`, the `2025-11-25` initialize lifecycle, separate stateless requests, reused JSON-RPC IDs, no modern method/name headers, and a legacy `_meta` signal on `tools/call`.

That test exists to prevent a future MCP-2026 cleanup from accidentally breaking current hosted clients while both protocol eras are in use.
