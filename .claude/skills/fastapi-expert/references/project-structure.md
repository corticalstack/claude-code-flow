# Project Structure

## Domain-Based Layout

Organize by domain, not by file type. Flat `models/`, `schemas/`, `routers/` directories
do not scale — domain modules keep related code collocated.

```
myapp/
├── app/
│   ├── main.py                  # App factory: creates FastAPI(), registers lifespan + routers
│   ├── config.py                # Pydantic Settings + get_settings()
│   ├── database.py              # DatabaseSessionManager, Base, get_db_session
│   ├── dependencies.py          # Shared cross-domain dependencies
│   ├── exceptions.py            # Custom exception handlers
│   ├── middleware.py            # Custom middleware (security headers, etc.)
│   │
│   ├── api/
│   │   ├── router.py            # Root APIRouter: includes v1
│   │   └── v1/
│   │       └── router.py        # Aggregates domain routers for v1
│   │
│   ├── auth/                    # Domain module
│   │   ├── router.py            # Route handlers only — no business logic
│   │   ├── schemas.py           # Pydantic request/response models
│   │   ├── service.py           # Business logic — testable without HTTP
│   │   ├── dependencies.py      # Auth-specific deps (get_current_user, etc.)
│   │   ├── constants.py
│   │   └── exceptions.py
│   │
│   ├── users/                   # Same structure per domain
│   │   ├── router.py
│   │   ├── schemas.py
│   │   ├── models.py            # SQLAlchemy ORM models
│   │   ├── service.py
│   │   └── dependencies.py
│   │
│   └── core/
│       ├── security.py          # JWT, password hashing
│       └── logging.py
│
├── migrations/                  # Alembic
│   └── versions/
├── tests/
│   ├── conftest.py              # Fixtures: engine, db, client, auth_headers
│   ├── test_auth.py
│   └── test_users.py
├── pyproject.toml
├── Dockerfile
├── docker-compose.yml
├── alembic.ini
└── .env.example
```

## `main.py` — App Factory

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.api.router import root_router
from app.database import sessionmanager
from app.middleware import SecurityHeadersMiddleware
from fastapi.middleware.cors import CORSMiddleware
from app.config import get_settings

settings = get_settings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    yield
    # Shutdown
    await sessionmanager.close()

def create_app() -> FastAPI:
    app = FastAPI(
        title="My API",
        version="1.0.0",
        lifespan=lifespan,
    )
    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(root_router, prefix="/api")
    return app

app = create_app()
```

## Layer Responsibilities

| Layer | Responsibility | Should NOT |
|-------|---------------|-----------|
| `router.py` | Parse request, call service, return response | Contain business logic or DB queries |
| `service.py` | Business logic, orchestration | Know about HTTP (no `Request`, `HTTPException`) |
| `models.py` | SQLAlchemy ORM entities | Contain business logic |
| `schemas.py` | Pydantic request/response shapes | Reference ORM models directly |
| `dependencies.py` | Build and inject shared objects | Contain business logic |

## Module Imports

Use explicit paths — avoid star imports and relative `..` chains beyond one level:

```python
# ✅ Clear and greppable
from app.auth import constants as auth_constants
from app.notifications import service as notification_service
from app.users.schemas import UserOut

# ❌ Fragile — breaks on restructure
from ..auth.constants import *
from ...core import something
```

## `pyproject.toml` — Canonical Dependency List

```toml
[project]
name = "my-fastapi-app"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi[standard]",       # Includes uvicorn, pydantic, email-validator
    "sqlalchemy[asyncio]>=2.0",
    "asyncpg",                 # PostgreSQL async driver
    "alembic",
    "pydantic-settings",
    "PyJWT",                   # NOT python-jose
    "passlib[bcrypt]",
    "slowapi",                 # Rate limiting
]

[dependency-groups]
dev = [
    "pytest>=8.0",
    "pytest-asyncio",
    "anyio[trio]",
    "httpx",
    "aiosqlite",               # SQLite for tests
    "asgi-lifespan",           # Trigger lifespan in tests
    "ruff",
    "mypy",
]

[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "session"

[tool.ruff.lint]
select = ["E", "F", "I", "UP"]
```

## Dockerfile (with uv)

```dockerfile
FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-cache --no-dev

COPY . .
CMD ["uv", "run", "fastapi", "run", "app/main.py", "--host", "0.0.0.0", "--port", "8000"]
```
