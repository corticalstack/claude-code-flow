# MCP Tools Reference

## Tool Definition

Tools are functions that AI assistants can invoke to perform actions or retrieve data.

```typescript
{
  "name": "get_weather",              // machine identifier: A-Za-z0-9_-. only, 1–128 chars
  "title": "Get Weather",             // optional human-readable display name (since 2025-11-25)
  "description": "Get current weather for a location. Returns temperature and conditions.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "location": { "type": "string", "description": "City name or zip code" }
    },
    "required": ["location"]
  },
  "annotations": {                    // advisory hints for client UX (since 2025-03-26)
    "readOnlyHint": true,             // does not modify environment
    "destructiveHint": false,         // no destructive side effects
    "idempotentHint": true,           // same args → same result, safe to retry
    "openWorldHint": true             // interacts with external services
  }
}
```

## Tool Naming (Updated `2025-11-25`)

**Rules (enforced by spec):**
- Length: **1–128 characters**
- Allowed characters: `A-Z`, `a-z`, `0-9`, `_` (underscore), `-` (hyphen), `.` (dot)
- **Not allowed:** spaces, `/` (slash), `,` (comma), or any other special characters
- Case-sensitive; must be unique within a server

```typescript
// ✅ Valid
"get_weather"
"DATA_EXPORT_v2"
"admin.tools.list"
"search-docs"

// ❌ Invalid
"get weather"        // space not allowed
"tools/search"       // slash not allowed
"create,delete"      // comma not allowed
```

**`title` field** (optional, since `2025-11-25`): Human-readable display name shown in UIs — no character restrictions. Use it when the machine name is abbreviated or opaque:

```typescript
{ "name": "kb_sem_srch", "title": "Knowledge Base Semantic Search" }
```

## Tool Annotations (Since `2025-03-26`)

Annotations are **advisory hints** for client UX — they help clients decide whether to show confirmation dialogs, warnings, or retry buttons. They are NOT enforced by the protocol.

> **Security note:** Clients MUST treat annotations as untrusted unless the server is explicitly trusted. A malicious server could misrepresent `destructiveHint`.

| Annotation | Default | Set to `true` when... |
|------------|---------|----------------------|
| `readOnlyHint` | `false` | Tool only reads data, never modifies anything |
| `destructiveHint` | `true` | Tool may permanently delete or overwrite data |
| `idempotentHint` | `false` | Same args multiple times has no additional effect |
| `openWorldHint` | `true` | Tool may interact with external systems (internet, external APIs) |

**Annotation patterns by operation type:**

```typescript
// Read-only internal tool (search, list, get)
"annotations": { "readOnlyHint": true,  "destructiveHint": false, "idempotentHint": true,  "openWorldHint": false }

// External API fetch (read-only but calls out)
"annotations": { "readOnlyHint": true,  "destructiveHint": false, "idempotentHint": true,  "openWorldHint": true  }

// Create / append (additive, not destructive)
"annotations": { "readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false }

// Delete / overwrite
"annotations": { "readOnlyHint": false, "destructiveHint": true,  "idempotentHint": false, "openWorldHint": false }
```

### Python SDK

```python
from mcp.types import Tool, ToolAnnotations

@app.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="search_docs",
            title="Search Documentation",
            description="Search documentation using semantic search. Returns top 5 results.",
            inputSchema=SearchArgs.model_json_schema(),
            annotations=ToolAnnotations(
                readOnlyHint=True,
                destructiveHint=False,
                idempotentHint=True,
                openWorldHint=False,
            ),
        ),
        Tool(
            name="delete_record",
            title="Delete Record",
            description="Permanently delete a record by ID.",
            inputSchema=DeleteArgs.model_json_schema(),
            annotations=ToolAnnotations(
                readOnlyHint=False,
                destructiveHint=True,
                idempotentHint=True,   # deleting same ID twice has no extra effect
                openWorldHint=False,
            ),
        ),
    ]
```

### TypeScript SDK

```typescript
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "search_docs",
        title: "Search Documentation",
        description: "Search documentation using semantic search. Returns top 5 results.",
        inputSchema: { /* ... */ },
        annotations: {
          readOnlyHint: true,
          destructiveHint: false,
          idempotentHint: true,
          openWorldHint: false,
        },
      },
    ],
  };
});
```

## Input Schema Patterns

**JSON Schema dialect:** Default is **JSON Schema 2020-12** (changed in `2025-11-25`; previously draft-07 was common). To use draft-07 explicitly, add `"$schema": "http://json-schema.org/draft-07/schema#"`. The `inputSchema` MUST be a valid JSON Schema object — `null` is not allowed. For tools with no parameters, use `{ "type": "object", "additionalProperties": false }`.

### Simple String Parameter

```typescript
{
  "name": "search_docs",
  "description": "Search documentation for a query",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "Search query",
        "minLength": 1
      }
    },
    "required": ["query"]
  }
}
```

### Enum Values

```typescript
{
  "name": "get_weather",
  "description": "Get weather information",
  "inputSchema": {
    "type": "object",
    "properties": {
      "location": { "type": "string" },
      "units": {
        "type": "string",
        "enum": ["celsius", "fahrenheit"],
        "default": "celsius",
        "description": "Temperature units"
      }
    },
    "required": ["location"]
  }
}
```

### Nested Objects

```typescript
{
  "name": "create_task",
  "description": "Create a new task",
  "inputSchema": {
    "type": "object",
    "properties": {
      "title": { "type": "string", "minLength": 1 },
      "metadata": {
        "type": "object",
        "properties": {
          "priority": { "type": "string", "enum": ["low", "medium", "high"] },
          "tags": { "type": "array", "items": { "type": "string" } }
        }
      }
    },
    "required": ["title"]
  }
}
```

### Array Parameters

```typescript
{
  "name": "batch_process",
  "description": "Process multiple items",
  "inputSchema": {
    "type": "object",
    "properties": {
      "items": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "id": { "type": "string" },
            "action": { "type": "string", "enum": ["update", "delete"] }
          },
          "required": ["id", "action"]
        },
        "minItems": 1,
        "maxItems": 100
      }
    },
    "required": ["items"]
  }
}
```

### Union Types (anyOf)

```typescript
{
  "name": "search",
  "description": "Search by ID or query",
  "inputSchema": {
    "type": "object",
    "properties": {
      "search": {
        "anyOf": [
          { "type": "string", "description": "Search query" },
          { "type": "number", "description": "Item ID" }
        ]
      }
    },
    "required": ["search"]
  }
}
```

## Tool Response Formats

### Text Response

```typescript
{
  "content": [
    {
      "type": "text",
      "text": "Operation completed successfully"
    }
  ]
}
```

### Multiple Content Blocks

```typescript
{
  "content": [
    { "type": "text", "text": "Found 3 results:" },
    { "type": "text", "text": "1. First result\n2. Second result\n3. Third result" }
  ]
}
```

### Image Content

```typescript
{
  "content": [
    {
      "type": "image",
      "data": "base64-encoded-image-data",
      "mimeType": "image/png"
    }
  ]
}
```

### Resource Reference

```typescript
{
  "content": [
    {
      "type": "resource",
      "resource": {
        "uri": "file:///data/results.json",
        "mimeType": "application/json",
        "text": "{\"results\": [...]}"
      }
    }
  ]
}
```

## Structured Output (Since `2025-06-18`)

Tools can declare an `outputSchema` (JSON Schema) and return machine-readable `structuredContent` alongside the human-readable `content` array. Useful for tool chaining and agent workflows.

```typescript
// Tool definition with outputSchema
{
  "name": "get_user",
  "description": "Get a user by ID",
  "inputSchema": {
    "type": "object",
    "properties": { "id": { "type": "string" } },
    "required": ["id"]
  },
  "outputSchema": {
    "type": "object",
    "properties": {
      "id":    { "type": "string" },
      "name":  { "type": "string" },
      "email": { "type": "string" }
    },
    "required": ["id", "name", "email"]
  }
}
```

Response:
```typescript
{
  "content": [
    { "type": "text", "text": "User: Alice (alice@example.com)" }   // for LLM/human display
  ],
  "structuredContent": {                                              // for programmatic use
    "id": "user-123",
    "name": "Alice",
    "email": "alice@example.com"
  }
}
```

> **Backward compatibility:** When returning `structuredContent`, always also serialize the data into a `TextContent` block. Old clients that don't understand `structuredContent` will still get a usable response.

## Tool Implementation Patterns

### Database Query Tool

```typescript
// TypeScript
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name === "query_database") {
    const { table, filter, limit } = request.params.arguments as {
      table: string;
      filter?: Record<string, any>;
      limit?: number;
    };

    // Validate table name (prevent SQL injection)
    if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(table)) {
      throw new McpError(ErrorCode.InvalidParams, "Invalid table name");
    }

    const results = await db.query(table, filter, limit || 10);

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(results, null, 2),
        },
      ],
    };
  }
});
```

```python
# Python
@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    if name == "query_database":
        args = QueryArgs(**arguments)  # Pydantic validation

        # Validate table name
        if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', args.table):
            raise ValueError("Invalid table name")

        results = await db.query(args.table, args.filter, args.limit)

        return [
            TextContent(type="text", text=json.dumps(results, indent=2))
        ]
```

### File System Tool

```typescript
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name === "read_file") {
    const { path } = request.params.arguments as { path: string };

    // Security: validate path is within allowed directory
    const safePath = resolvePath(ALLOWED_DIR, path);
    if (!safePath.startsWith(ALLOWED_DIR)) {
      throw new McpError(ErrorCode.InvalidParams, "Access denied");
    }

    const content = await fs.readFile(safePath, "utf-8");

    return {
      content: [{ type: "text", text: content }],
    };
  }
});
```

### HTTP API Tool

```python
@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    if name == "fetch_api":
        args = FetchArgs(**arguments)

        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(
                    args.url,
                    timeout=30.0,
                    headers={"User-Agent": "MCP Server"}
                )
                response.raise_for_status()

                return [
                    TextContent(
                        type="text",
                        text=response.text
                    )
                ]
            except httpx.HTTPError as e:
                raise McpError(INTERNAL_ERROR, f"HTTP request failed: {e}")
```

### Async Background Task

```typescript
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name === "start_job") {
    const { jobType, params } = request.params.arguments as {
      jobType: string;
      params: Record<string, any>;
    };

    const jobId = await jobQueue.enqueue(jobType, params);

    return {
      content: [{ type: "text", text: `Job started with ID: ${jobId}` }],
    };
  }

  if (request.params.name === "check_job") {
    const { jobId } = request.params.arguments as { jobId: string };
    const status = await jobQueue.getStatus(jobId);
    return {
      content: [{ type: "text", text: JSON.stringify(status, null, 2) }],
    };
  }
});
```

## Best Practices

### 1. Descriptive Names and Descriptions

```typescript
// Good
{
  "name": "search_knowledge_base",
  "title": "Knowledge Base Search",
  "description": "Search the knowledge base using semantic search. Returns top 5 relevant documents with excerpts.",
  "inputSchema": { ... }
}

// Bad
{
  "name": "search",
  "description": "Search",
  "inputSchema": { ... }
}
```

### 2. Input Validation

```python
class SearchArgs(BaseModel):
    query: str = Field(..., min_length=1, max_length=500)
    max_results: int = Field(default=5, ge=1, le=50)
    filters: dict[str, str] = Field(default_factory=dict)

    @field_validator("query")
    @classmethod
    def validate_query(cls, v: str) -> str:
        return v.strip()
```

### 3. Error Handling

```typescript
try {
  const result = await executeOperation(params);
  return { content: [{ type: "text", text: result }] };
} catch (error) {
  if (error instanceof ValidationError) {
    throw new McpError(ErrorCode.InvalidParams, error.message);
  }
  if (error instanceof NotFoundError) {
    return {
      content: [{ type: "text", text: "Resource not found" }],
      isError: true,
    };
  }
  throw new McpError(ErrorCode.InternalError, `Operation failed: ${error.message}`);
}
```

### 4. Rate Limiting

```python
from asyncio import Lock
from datetime import datetime, timedelta

rate_limiter: dict[str, list] = {}
rate_limit_lock = Lock()

async def check_rate_limit(tool_name: str, limit: int = 10) -> None:
    async with rate_limit_lock:
        now = datetime.now()
        rate_limiter.setdefault(tool_name, [])
        rate_limiter[tool_name] = [
            t for t in rate_limiter[tool_name]
            if now - t < timedelta(minutes=1)
        ]
        if len(rate_limiter[tool_name]) >= limit:
            raise McpError(-32004, "Rate limit exceeded")
        rate_limiter[tool_name].append(now)
```

### 5. Idempotency

```typescript
{
  "name": "create_record",
  "inputSchema": {
    "type": "object",
    "properties": {
      "idempotency_key": {
        "type": "string",
        "description": "Unique key to prevent duplicate operations"
      },
      "data": { "type": "object" }
    },
    "required": ["idempotency_key", "data"]
  }
}
```

### 6. Timeouts

```python
@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    if name == "long_operation":
        try:
            result = await asyncio.wait_for(
                execute_operation(arguments),
                timeout=30.0
            )
            return [TextContent(type="text", text=str(result))]
        except asyncio.TimeoutError:
            raise McpError(INTERNAL_ERROR, "Operation timed out")
```

### 7. Logging

```typescript
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const startTime = Date.now();
  console.error(`[${new Date().toISOString()}] Tool call: ${request.params.name}`);

  try {
    const result = await executeTool(request.params.name, request.params.arguments);
    console.error(`[${new Date().toISOString()}] Tool completed in ${Date.now() - startTime}ms`);
    return result;
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Tool failed:`, error);
    throw error;
  }
});
```
