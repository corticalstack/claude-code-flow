# Error Responses (RFC 9457)

## Standard

All error responses use `Content-Type: application/problem+json` (RFC 9457, obsoletes RFC 7807).

**Core fields:**
- `type` — Stable URI identifying the problem. Use `"about:blank"` for generic HTTP errors where the status code meaning is sufficient.
- `title` — Short, human-readable summary. Consistent for a given `type`. Never include occurrence-specific data.
- `status` — HTTP status code (integer).
- `detail` — Human-readable, actionable explanation specific to this occurrence.
- `instance` — URI of the request path.
- `trace_id` — Always include. Log full error details server-side keyed on this value.

## FastAPI Exception Handlers

Override FastAPI's defaults so all errors emit RFC 9457:

```python
import uuid
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

ERROR_BASE_URL = "https://api.example.com/errors"


def problem_response(
    status_code: int,
    type_suffix: str,
    title: str,
    detail: str,
    request: Request,
    **extra,
) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "type": f"{ERROR_BASE_URL}/{type_suffix}",
            "title": title,
            "status": status_code,
            "detail": detail,
            "instance": str(request.url.path),
            "trace_id": str(uuid.uuid4()),
            **extra,
        },
        media_type="application/problem+json",
    )


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(request: Request, exc: StarletteHTTPException):
        return problem_response(
            status_code=exc.status_code,
            type_suffix=f"http-{exc.status_code}",
            title=exc.detail if isinstance(exc.detail, str) else "HTTP Error",
            detail=exc.detail if isinstance(exc.detail, str) else str(exc.detail),
            request=request,
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        return problem_response(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            type_suffix="validation-error",
            title="Validation Error",
            detail="The request body contains invalid field values.",
            request=request,
            invalid_params=[
                {
                    "name": ".".join(str(loc) for loc in e["loc"][1:]),
                    "reason": e["msg"],
                }
                for e in exc.errors()
            ],
        )
```

Register in your app factory:
```python
app = FastAPI()
register_exception_handlers(app)
```

For domain-specific errors, call `problem_response` directly to set a specific `type_suffix`. Using `raise HTTPException(404)` generates a generic `type` URI; calling `problem_response` directly gives you a specific, documented one:

```python
# Generic type URI — OK for simple cases
raise HTTPException(404, detail=f"User '{user_id}' was not found.")

# Specific type URI — preferred for documented error types
return problem_response(404, "user-not-found", "Not Found",
                        f"User '{user_id}' was not found.", request)
```

## Status Codes

| Code | When | Notes |
|------|------|-------|
| **400** | Malformed request (unparseable JSON, wrong `Content-Type`) | Starlette raises automatically |
| **401** | Missing or invalid authentication | Include `WWW-Authenticate` header |
| **403** | Authenticated but lacks permission | |
| **404** | Resource not found | |
| **409** | Conflict — duplicate resource, optimistic lock failure | |
| **410** | Resource permanently deleted | Prefer over 404 when the deletion is known |
| **422** | Pydantic validation failure | FastAPI default; override handler above converts to RFC 9457 |
| **429** | Rate limited | Include `Retry-After` + `RateLimit` headers |
| **500** | Unexpected error | Never expose stack traces — log with `trace_id` |
| **503** | Service unavailable | Include `Retry-After` |

### 400 vs 422
FastAPI/Pydantic returns **422** for type/value validation failures — this is correct. Use **400** only when the request cannot be parsed at all (JSON syntax error, wrong `Content-Type`).

### 404 vs 410
Return **410 Gone** when you know the resource existed but was permanently deleted (e.g. soft-delete records). 410 signals to clients and crawlers to stop requesting the resource.

## Never Expose Internals

```python
# ❌ BAD — leaks implementation details
raise HTTPException(500, detail=str(exception))

# ✅ GOOD — log full error server-side, return only trace_id
raise HTTPException(500, detail="An unexpected error occurred.")
```

## Rate Limit Headers on 429

```http
Retry-After: 60
RateLimit: "default";r=0;t=60
RateLimit-Policy: "default";q=100;w=3600
```

Also include `Retry-After` on **503** responses.

## Retryable Errors

| Code | Retryable? |
|------|-----------|
| 400, 401, 403, 404, 409, 410, 422 | No |
| 429, 502, 503, 504 | Yes — after `Retry-After` |
| 500 | Sometimes — check `trace_id` in logs |
