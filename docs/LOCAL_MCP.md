# Sympho Local MCP

Sympho hosts its MCP server inside the macOS app. The app must remain running. The server listens only on `127.0.0.1` and defaults to `http://127.0.0.1:8765/mcp`.

## Setup

1. Open Sympho Settings and enable **Local MCP**.
2. Optionally add approved folders for attachment import/read access.
3. Use the copy button for Codex, Claude Code, or Cursor and confirm the credential warning.
4. Paste the generated configuration into that client's MCP configuration, then restart or reconnect the client.
5. Use **Test connection** in Sympho. The Settings panel reports server state, clients, last client, and last call.

The copied bearer token is a 256-bit secret stored in Keychain. Rotating it restarts the server and immediately invalidates configurations containing the previous token.

## Agent workflow

Agents should call `get_workspace_schema`, then search/list before using UUID-based writes. Creates, relationship changes, and learning-plan batches require idempotency keys. Writes are serialized through `SymphoWorkspaceService`, committed once, audited, and exposed in Agent Activity. Undo refuses to overwrite a record that differs from the audited post-write snapshot.

Attachments may be imported only from security-scoped approved roots. Paths are standardized and symlinks resolved before the containment check. External originals are never deleted; Sympho archives metadata and manages only its own imported copy.

## Development smoke-test overrides

An isolated development instance can use `SYMPHO_IN_MEMORY_STORE=1`, `SYMPHO_MCP_ENABLED=1`, and `SYMPHO_MCP_TOKEN=<test token>`. These overrides are intended for protocol tests and do not replace production Keychain authentication.

## Remote evolution

The transport/authentication layer is intentionally separate from the Codable DTOs, tool catalog, workspace service, validation, audit, and undo logic. A future hosted MCP should reuse those layers, replace loopback bearer authentication with user-scoped OAuth, and replace direct local SwiftData access with an authorized persistence adapter.
