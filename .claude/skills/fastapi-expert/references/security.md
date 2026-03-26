# Security

## CORS

Never combine `allow_origins=["*"]` with `allow_credentials=True` — browsers will reject it.

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.yourdomain.com"],  # Never "*" with credentials
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
```

## Middleware Stack

Order matters — middlewares wrap in reverse (last added, first executed for responses).

```python
from starlette.middleware.trustedhost import TrustedHostMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

# Add in this order
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["yourdomain.com", "*.yourdomain.com"],
)
app.add_middleware(CORSMiddleware, ...)  # CORS should wrap everything
```

## Security Headers Middleware

```python
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        # X-XSS-Protection is disabled in modern browsers; use CSP instead
        response.headers["X-XSS-Protection"] = "0"
        return response

app.add_middleware(SecurityHeadersMiddleware)
```

## Rate Limiting (SlowAPI)

```python
# pip install slowapi
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi import Request

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@router.post("/auth/login")
@limiter.limit("5/minute")  # Strict on sensitive endpoints
async def login(request: Request, ...):
    ...

@router.get("/items/")
@limiter.limit("100/minute")
async def list_items(request: Request, ...):
    ...
```

For distributed deployments, configure SlowAPI with a Redis backend for shared counters across instances.

## Async Route Rules

```python
# WRONG — blocks the entire event loop
@app.get("/bad")
async def bad_route():
    time.sleep(1)           # Never block in async def
    requests.get(url)       # Never use sync HTTP client in async def
    return {}

# RIGHT — non-blocking I/O
@app.get("/good-io")
async def good_io_route(db: DB):
    result = await db.execute(select(User))  # Non-blocking
    return result.scalars().all()

# RIGHT — CPU-bound: use sync def (FastAPI runs in threadpool automatically)
@app.get("/cpu-bound")
def cpu_bound_route():
    return {"result": heavy_computation()}

# RIGHT — forced sync SDK in async context
@app.get("/sync-sdk")
async def sync_sdk_route():
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, sync_sdk_call)
    return result
```

## Background Tasks

Use `BackgroundTasks` for lightweight post-response work. For heavy tasks use Celery or ARQ.

```python
from fastapi import BackgroundTasks

@router.post("/send-notification/")
async def send_notification(email: str, background_tasks: BackgroundTasks) -> dict:
    background_tasks.add_task(send_email_async, email)
    return {"message": "Notification scheduled"}
```

## Quick Reference

| Topic | Rule |
|-------|------|
| CORS with credentials | Never `allow_origins=["*"]` — use explicit list |
| Rate limiting | SlowAPI with Redis backend for multi-instance |
| Security headers | `X-Frame-Options`, `HSTS`, `X-Content-Type-Options` |
| XSS protection | Use CSP header; disable `X-XSS-Protection` (deprecated) |
| `async def` routes | Never block with `time.sleep`, sync HTTP, sync DB |
| CPU-bound routes | Use `def` not `async def` — FastAPI uses threadpool |
| Background tasks | `BackgroundTasks` for lightweight; Celery/ARQ for heavy |
