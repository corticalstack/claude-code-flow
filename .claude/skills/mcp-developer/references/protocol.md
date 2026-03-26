# MCP Protocol Specification

## Protocol Overview

MCP is built on JSON-RPC 2.0 and enables bidirectional communication between clients
(like Claude Desktop) and servers that provide resources, tools, and prompts.

Current spec: **`2025-11-25`**

## Message Types

### Request/Response

```typescript
// Request format
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {}
}

// Success response
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "get_weather",
        "title": "Get Weather",
        "description": "Get weather for a location",
        "inputSchema": {
          "type": "object",
          "properties": {
            "location": { "type": "string" }
          },
          "required": ["location"]
        },
        "annotations": { "readOnlyHint": true, "openWorldHint": true }
      }
    ]
  }
}

// Error response
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": { "details": "location is required" }
  }
}
```

### Notifications

```typescript
// Server sends notification (no response expected)
{
  "jsonrpc": "2.0",
  "method": "notifications/resources/updated",
  "params": {
    "uri": "file:///project/data.json"
  }
}
```

## Connection Lifecycle

```
1. Client initiates connection (stdio or Streamable HTTP)
2. Client sends initialize request
   → Server responds with capabilities
3. Client sends initialized notification
4. Normal operation (requests/notifications)
5. Client/server can ping for keepalive
6. Client sends shutdown request
7. Connection closes
```

### Initialize Handshake

```typescript
// Client initialize request
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-11-25",
    "capabilities": {
      "roots": { "listChanged": true },
      "sampling": { "tools": {} },
      "elicitation": {}
    },
    "clientInfo": { "name": "claude-desktop", "version": "1.0.0" }
  }
}

// Server response
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2025-11-25",
    "capabilities": {
      "resources": { "subscribe": true, "listChanged": true },
      "tools": { "listChanged": true },
      "prompts": { "listChanged": true },
      "elicitation": {}
    },
    "serverInfo": { "name": "my-mcp-server", "version": "1.0.0" }
  }
}

// Client sends initialized notification
{
  "jsonrpc": "2.0",
  "method": "notifications/initialized"
}
```

## Core Methods

### Resources
- `resources/list` → `{ resources: Resource[] }`
- `resources/read { uri: string }` → `{ contents: ResourceContent[] }`
- `resources/subscribe { uri: string }` → `{}`
- `resources/unsubscribe { uri: string }` → `{}`
- `notifications/resources/list_changed` → `{}`
- `notifications/resources/updated { uri: string }` → `{}`

### Tools
- `tools/list` → `{ tools: Tool[] }` — tools now include `title`, `annotations`, and optional `outputSchema`
- `tools/call { name: string, arguments: object }` → `{ content: ToolResponse[], structuredContent?: object }` — `structuredContent` added `2025-06-18`
- `notifications/tools/list_changed` → `{}`

### Prompts
- `prompts/list` → `{ prompts: Prompt[] }`
- `prompts/get { name: string, arguments?: object }` → `{ messages: PromptMessage[] }`
- `notifications/prompts/list_changed` → `{}`

### Sampling (Client capability)
- `sampling/createMessage { messages, modelPreferences?, systemPrompt?, maxTokens }` → `{ role, content, model, stopReason }`
- Servers request LLM completions through the client; the client controls model selection and approval

### Elicitation (Since `2025-06-18`)
- `elicitation/create { message, requestedSchema }` → `{ action: "accept"|"decline"|"cancel", content? }`
- Servers request structured user input; client surfaces a form or URL prompt
- Declare capability: `"elicitation": {}` in server capabilities

### Tasks (Experimental, Since `2025-11-25`)
- `tasks/list` → `{ tasks: Task[] }`
- `tasks/get { id: string }` → `{ task: Task }`
- `notifications/tasks/updated { id, status }` → `{}`
- Task lifecycle states: `submitted` → `working` → `completed` | `failed` | `canceled`

## Error Codes

```typescript
const ERROR_CODES = {
  PARSE_ERROR: -32700,
  INVALID_REQUEST: -32600,
  METHOD_NOT_FOUND: -32601,
  INVALID_PARAMS: -32602,
  INTERNAL_ERROR: -32603,
  RESOURCE_NOT_FOUND: -32001,
  TOOL_EXECUTION_ERROR: -32002,
  UNAUTHORIZED: -32003,
  RATE_LIMIT_EXCEEDED: -32004,
  PUSH_NOTIFICATION_FAILED: -32042   // added 2025-11-25
};
```

## Transport Mechanisms

| Transport | Use Case | Status |
|-----------|----------|--------|
| **stdio** | Local/subprocess (Claude Desktop) | Preferred for local |
| **Streamable HTTP** | Remote servers over HTTPS | **Preferred for remote** (since `2025-03-26`) |
| HTTP+SSE | Old two-endpoint pattern | **Deprecated** since `2025-03-26` |

**stdio:** Server reads from stdin, writes to stdout. Newline-delimited JSON. Client spawns the server as a subprocess. All logging MUST go to stderr.

**Streamable HTTP (single endpoint):**
- Client → Server: HTTP POST `Content-Type: application/json`
- Server → Client (response): `application/json` or `text/event-stream` (SSE)
- Server → Client (push): Client opens SSE stream via HTTP GET to same endpoint
- Session management: `Mcp-Session-Id` header; resumability via `Last-Event-ID`

See `transport.md` for full implementation examples.

## Best Practices

1. Always validate params with JSON Schema / Pydantic / Zod
2. Return structured errors with helpful messages — never expose stack traces
3. Check and negotiate `protocolVersion` in initialize (support latest + prior version)
4. Implement request timeouts (30s recommended for tool calls)
5. Log all protocol messages to stderr for debugging (never stdout)
6. Use **Streamable HTTP** for remote deployments; **stdio** for local
7. Validate `Origin` header on every Streamable HTTP request (DNS rebinding protection)
8. Bind local HTTP servers to `127.0.0.1`, not `0.0.0.0`
9. Servers MUST obtain their own tokens — never pass through client tokens to upstream APIs
10. Annotate every tool with `readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`
11. Design tools/resources to be stateless where possible
12. Declare `elicitation` capability only if the client supports it; always handle `"cancel"` action
