# MCP Transport Reference

## Quick Reference

| Transport | Use Case | Status |
|-----------|----------|--------|
| **stdio** | Local/subprocess (Claude Desktop) | Preferred for local |
| **Streamable HTTP** | Remote servers over HTTPS | **Preferred for remote** (since `2025-03-26`) |
| HTTP+SSE | Old two-endpoint pattern | **Deprecated** since `2025-03-26` |

---

## stdio

Server reads JSON-RPC from **stdin**, writes to **stdout**. Newline-delimited JSON. Client spawns the server as a subprocess.

**Spec:** "Clients SHOULD support stdio whenever possible."

**Critical:** Never write to stdout in server code — stderr only. stdout is reserved exclusively for the protocol stream.

### Python

```python
from mcp.server.stdio import stdio_server
import asyncio

async def main():
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())

asyncio.run(main())
```

### TypeScript

```typescript
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("MCP Server running on stdio");  // stderr only
}

main().catch(console.error);
```

---

## Streamable HTTP (Preferred for Remote Servers)

Introduced in spec `2025-03-26`, replacing the old HTTP+SSE transport. A **single endpoint** handles all communication.

### Architecture

| Direction | Mechanism |
|-----------|-----------|
| Client → Server | HTTP POST `Content-Type: application/json` |
| Server → Client (response) | `application/json` (single) or `text/event-stream` (SSE, multiple) |
| Server → Client (push) | Client opens SSE stream via HTTP GET to same endpoint |

**Session management:** `Mcp-Session-Id` header identifies sessions across requests.
**Resumability:** `Last-Event-ID` + event IDs allow stream resumption after disconnect.

### Security Requirements (MUST)

- **Validate `Origin` header** on every request — prevents DNS rebinding attacks
- **Bind local servers to `127.0.0.1`**, not `0.0.0.0`
- Require authentication on every request, not just at connection handshake

### Python SDK

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("my-server")

# Register tools/resources with decorators
@mcp.tool()
async def search_docs(query: str) -> str:
    """Search documentation."""
    ...

# Standalone server (binds to 127.0.0.1:8000 by default)
if __name__ == "__main__":
    mcp.run(transport="streamable-http")

# With custom path
    mcp.run(transport="streamable-http", mount_path="/mcp")

# Stateless mode (for horizontally scalable deployments — no subscriptions/sampling)
    mcp.run(transport="streamable-http", stateless_http=True, json_response=True)
```

Mount onto an existing FastAPI app:
```python
from fastapi import FastAPI

app = FastAPI()
app.mount("/", mcp.streamable_http_app())
```

### TypeScript SDK

**Stateless** (pure tool servers, no server-initiated messages):
```typescript
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";

const app = express();
app.use(express.json());

app.post("/mcp", async (req, res) => {
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,  // undefined = stateless
  });
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
  res.on("finish", () => server.close());
});

app.listen(3000, "127.0.0.1");  // bind to localhost only
```

**Stateful** (with subscriptions, sampling, or elicitation):
```typescript
import { randomUUID } from "node:crypto";

const sessions = new Map<string, StreamableHTTPServerTransport>();

app.post("/mcp", async (req, res) => {
  const sessionId = req.headers["mcp-session-id"] as string | undefined;

  let transport: StreamableHTTPServerTransport;
  if (sessionId && sessions.has(sessionId)) {
    transport = sessions.get(sessionId)!;
  } else {
    transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => randomUUID(),
    });
    await server.connect(transport);
    sessions.set(transport.sessionId!, transport);
  }

  await transport.handleRequest(req, res, req.body);
});

// SSE stream endpoint for server-initiated push
app.get("/mcp", async (req, res) => {
  const sessionId = req.headers["mcp-session-id"] as string;
  const transport = sessions.get(sessionId);
  if (!transport) { res.status(404).end(); return; }
  await transport.handleRequest(req, res);
});
```

### Stateful vs Stateless

| Mode | When to Use |
|------|-------------|
| **Stateless** (`sessionIdGenerator: undefined`) | Pure tool servers; no subscriptions, sampling, or elicitation |
| **Stateful** | Servers that push notifications, or use sampling/elicitation |

---

## Deprecated: HTTP+SSE

The old transport used two separate endpoints:
- `GET /sse` — SSE stream for server→client messages
- `POST /messages` — client→server messages

**Deprecated since `2025-03-26`.** Do not use for new implementations.

### Migration Path

To support both old and new clients during a transition:
1. Add new `/mcp` endpoint (Streamable HTTP)
2. Keep old `/sse` + `/messages` endpoints
3. New clients POST to `/mcp`; old clients GET `/sse`

Client discovery: try `POST /mcp` first; fall back to `GET /sse` on HTTP 4xx.
