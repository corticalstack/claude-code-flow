---
name: fastapi-expert
description: Use when building FastAPI applications, async Python REST APIs, Pydantic V2 schemas, SQLAlchemy async database operations, JWT/OAuth2 authentication, async pytest testing, RFC 9457 error handling, cursor pagination, or API versioning strategies.
license: MIT
metadata:
  author: https://github.com/corticalstack
  version: "1.0.0"
  domain: backend-api
  triggers: FastAPI, Pydantic V2, async Python, REST API, SQLAlchemy async, JWT, OAuth2, async testing, pytest-asyncio, httpx AsyncClient, PyJWT, uv, lifespan, RFC 9457, Problem Details, cursor pagination, API versioning, idempotency
  role: backend-engineer
  scope: implementation
  output-format: code
  related-skills: python-pro
---

# FastAPI Expert Skill Profile

Specialized backend implementation guide for production-grade async Python APIs using **FastAPI 0.115+**, **Pydantic V2**, **SQLAlchemy 2.0 async**, and **Python 3.12+**.

## Critical Requirements (MUST DO)
- Type hints throughout — FastAPI and Pydantic depend on them
- Pydantic V2 syntax exclusively (`model_config`, `field_validator`, `ConfigDict`)
- `Annotated[T, Depends()]` type alias pattern for all dependencies
- `lifespan` context manager — never `@app.on_event` (deprecated, has a double-fire bug)
- `async def` for all I/O routes; `def` for CPU-bound routes (FastAPI runs those in a threadpool)
- `PyJWT` for JWT — **never `python-jose`** (CVE-2024-33663, abandoned since 2022)
- `uv` for dependency management, `ruff` for linting
- RFC 9457 Problem Details (`application/problem+json`) for all error responses — see `references/error-responses.md`
- Cursor-based pagination by default for all collection endpoints — see `references/pagination.md`
- URI prefix versioning from day one (`/v1/`) — never ship unversioned public endpoints
- `Idempotency-Key` header support for non-idempotent POST/PATCH operations
- `Retry-After` on all 429 and 503 responses

## Anti-Pattern Quick Reference

| ❌ Avoid | ✅ Use Instead |
|----------|---------------|
| `@app.on_event("startup/shutdown")` | `lifespan` context manager |
| `python-jose` / `jose` import | `PyJWT` (`import jwt`) |
| `ORJSONResponse` / `UJSONResponse` | Default Pydantic/Rust serializer (FastAPI 0.130+) |
| `Column()` in SQLAlchemy models | `mapped_column()` with `Mapped[]` |
| `orm_mode = True` / `class Config` | `model_config = ConfigDict(from_attributes=True)` |
| `.dict()` / `.json()` | `.model_dump()` / `.model_dump_json()` |
| `@pytest.mark.asyncio` on every test | `asyncio_mode = "auto"` in `pyproject.toml` |
| `TestClient` in async tests | `httpx.AsyncClient` with `ASGITransport` |
| `allow_origins=["*"]` + `allow_credentials=True` | Explicit origin list |
| `time.sleep()` in `async def` | `await asyncio.sleep()` or use `def` route |
| `pip` / `poetry` | `uv` |
| `Optional[X]` | `X \| None` (Python 3.10+) |
| `200 OK` with error in body | Proper 4xx/5xx + RFC 9457 `application/problem+json` |
| `{"error": {"message": ...}}` custom format | RFC 9457 Problem Details |
| `?page=N` offset pagination by default | Cursor pagination (`?cursor=...`) |
| Verb URIs (`/getUsers`, `/createUser`) | Noun resource URIs (`/users`) |
| Unversioned public endpoints | `/v1/` URI prefix on all routes |

## Reference Files

| File | Contents |
|------|----------|
| [references/pydantic-v2.md](references/pydantic-v2.md) | Schemas, validators, `ConfigDict`, `computed_field`, settings |
| [references/endpoints-routing.md](references/endpoints-routing.md) | Router setup, CRUD, query parameter models (0.115+), dependencies |
| [references/authentication.md](references/authentication.md) | PyJWT, OAuth2, RBAC, httpOnly cookies, refresh tokens |
| [references/async-sqlalchemy.md](references/async-sqlalchemy.md) | Engine, `AsyncAttrs`, `DatabaseSessionManager`, CRUD, lifespan |
| [references/testing-async.md](references/testing-async.md) | `anyio` auto mode, `AsyncClient`, `NullPool`, rollback isolation |
| [references/security.md](references/security.md) | CORS, rate limiting, security headers, middleware stack |
| [references/project-structure.md](references/project-structure.md) | Domain-based layout, app factory, module conventions |
| [references/error-responses.md](references/error-responses.md) | RFC 9457 Problem Details, FastAPI exception handlers, status code guide |
| [references/pagination.md](references/pagination.md) | Cursor pagination, async SQLAlchemy keyset queries, response envelope |
| [references/versioning.md](references/versioning.md) | URI versioning, `APIRouter` prefix, breaking changes, Sunset headers |
