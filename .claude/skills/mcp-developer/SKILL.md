---
name: mcp-developer
description: Use when building, debugging, or extending MCP servers or clients that
  connect AI systems with external tools and data sources. Invoke to implement tool
  handlers, configure resource providers, set up stdio/Streamable HTTP transport,
  validate schemas with Zod or Pydantic, debug protocol compliance issues, or scaffold
  complete MCP server/client projects using TypeScript or Python SDKs.
license: MIT
metadata:
  author: https://github.com/corticalstack
  version: "1.0.0"
  domain: api-architecture
  triggers: MCP, Model Context Protocol, MCP server, MCP client, Claude integration, AI tools, context protocol, JSON-RPC, Streamable HTTP, tool annotations, elicitation, MCP tasks, OAuth 2.1 MCP
  role: specialist
  scope: implementation
  output-format: code
  related-skills: fastapi-expert
---

## MCP Developer

Senior MCP developer expertise in constructing servers and clients linking AI systems to external tools and data sources. Current spec: **`2025-11-25`**.

## Core Workflow

1. Analyze requirements
2. Initialize project — `uv add "mcp[cli]>=1.25,<2"` (Python) or `npm i @modelcontextprotocol/sdk zod` (TypeScript)
3. Design protocol with resource URIs and tool schemas
4. Implement and register handlers with appropriate transport (stdio for local, Streamable HTTP for remote)
5. Test using MCP inspector to verify protocol compliance
6. Deploy with auth, rate-limiting, and monitoring

## Key Requirements

**Must implement:**
- JSON-RPC 2.0 protocol (`2025-11-25` spec)
- Input validation via schemas (Pydantic for Python, Zod for TypeScript)
- Transport: **stdio** for local, **Streamable HTTP** for remote (HTTP+SSE is deprecated since `2025-03-26`)
- Tool annotations on every tool (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`)
- Tool names: 1–128 chars, `A-Za-z0-9_-.` only (no spaces, slashes, commas)
- Error handling with `McpError` + JSON-RPC error codes
- Authentication (environment variables for stdio; OAuth 2.1 + PKCE for HTTP)
- Protocol logging, compliance testing, capability documentation

**Must avoid:**
- HTTP+SSE transport (old two-endpoint pattern — deprecated since `2025-03-26`)
- Tool names with spaces, slashes (`/`), commas, or other special chars
- Writing to stdout in stdio servers (use stderr for all logging)
- Token passthrough to upstream APIs (servers MUST obtain their own tokens)
- Exposing sensitive data or stack traces in error responses
- Mixing sync/async patterns; hardcoding secrets
- Deploying without rate limits or authentication

## Reference Files

| File | Contents |
|------|----------|
| [references/protocol.md](references/protocol.md) | JSON-RPC 2.0 message types, connection lifecycle, core methods, error codes |
| [references/transport.md](references/transport.md) | Streamable HTTP (current), stdio, deprecated HTTP+SSE, migration guide |
| [references/python-sdk.md](references/python-sdk.md) | Server/client setup, Pydantic validation, Streamable HTTP, error handling |
| [references/typescript-sdk.md](references/typescript-sdk.md) | Server/client setup, Zod validation, Streamable HTTP, error handling |
| [references/tools.md](references/tools.md) | Tool definitions, naming rules, annotations, structured output, input schemas |
| [references/resources.md](references/resources.md) | URI schemes, resource templates, content types, subscriptions, security |
