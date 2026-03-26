# API Versioning

## Strategy: URI Prefix (Recommended)

```
GET /v1/users/123
GET /v2/users/123
```

URI versioning is the most explicit, discoverable, and cacheable approach. Every major public API — Stripe, GitHub REST, Twilio — uses it. Version all public endpoints from day one; never ship an unversioned API.

## FastAPI: APIRouter Prefix

```
app/
  routers/
    v1/
      __init__.py
      users.py
      orders.py
    v2/
      __init__.py
      users.py        # only endpoints that changed
```

```python
# routers/v1/users.py
from fastapi import APIRouter

router = APIRouter(prefix="/v1/users", tags=["v1:users"])

@router.get("/{user_id}")
async def get_user_v1(user_id: str): ...
```

```python
# routers/v2/users.py
from fastapi import APIRouter
from app.routers.v1.users import get_user_v1  # reuse unchanged handlers

router = APIRouter(prefix="/v2/users", tags=["v2:users"])

# Override what changed; re-export unchanged handlers
router.add_api_route("/{user_id}", get_user_v1, methods=["GET"])

@router.post("/")
async def create_user_v2(...): ...  # new v2 behavior
```

```python
# main.py / app factory
from app.routers.v1 import users as v1_users
from app.routers.v2 import users as v2_users

app.include_router(v1_users.router)
app.include_router(v2_users.router)
```

**Tip:** Keep `/docs` readable by using `tags` with a version prefix (`v1:users`, `v2:users`). For large APIs, consider separate FastAPI apps per major version with independent `/docs`.

## Breaking vs Non-Breaking Changes

### Breaking — Requires New Version
- Removing or renaming response fields
- Changing field types (e.g. `string` → `integer`)
- Adding required request fields
- Changing HTTP method or URI
- Removing endpoints
- Changing authentication mechanism
- Changing pagination strategy or response envelope

### Non-Breaking — Safe to Ship in Current Version
- Adding new optional response fields (clients must ignore unknown fields)
- Adding new optional request parameters
- Adding new endpoints
- Bug fixes matching documented spec
- Performance improvements

## Deprecation Headers (RFC 8594)

Add to all responses from deprecated versions:

```python
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request


class V1DeprecationMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        if request.url.path.startswith("/v1/"):
            response.headers["Deprecation"] = "true"
            response.headers["Sunset"] = "Tue, 15 Jul 2026 00:00:00 GMT"
            response.headers["Link"] = '</v2/>; rel="successor-version"'
        return response


app.add_middleware(V1DeprecationMiddleware)
```

## Lifecycle

| Milestone | Timeline |
|-----------|----------|
| Announce deprecation | Day 0 — headers + changelog |
| Minimum support period | 6 months |
| Recommended support period | 12 months |
| Sunset (return 410) | After support period |

```python
# On sunset date — return 410 for all v1 routes via middleware or router override
raise HTTPException(
    status_code=410,
    detail="API v1 was sunset on 2026-07-15. Please migrate to /v2/.",
)
```

## Anti-Patterns

| ❌ Avoid | Problem |
|---------|---------|
| Breaking change without version bump | Silently breaks existing clients |
| Deprecation period < 3 months | Clients cannot react in time |
| > 3 active versions simultaneously | Maintenance and security burden |
| Versioning individual endpoints only | Inconsistent client experience |
| No migration guide | Forces manual discovery of all breaking changes |
| Query param versioning (`?version=2`) | Pollutes query string; does not cache cleanly |
