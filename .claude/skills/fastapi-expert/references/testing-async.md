# Async Testing

## Setup — `pyproject.toml`

`asyncio_mode = "auto"` eliminates `@pytest.mark.asyncio` on every test function.
`NullPool` prevents connection pool issues at function scope.

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "session"

[tool.anyio]
backends = ["asyncio"]

[dependency-groups]
dev = [
    "pytest>=8.0",
    "pytest-asyncio",
    "anyio[trio]",
    "httpx",
    "aiosqlite",    # SQLite async driver for tests
]
```

## `conftest.py`

```python
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import NullPool  # Required for function-scoped test sessions

from app.main import app
from app.database import get_db_session, Base

TEST_DATABASE_URL = "sqlite+aiosqlite:///./test.db"

@pytest.fixture(scope="session")
async def engine():
    # NullPool: no connection pooling — required for pytest-asyncio at function scope
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()

@pytest.fixture
async def db(engine) -> AsyncSession:
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    async with session_factory() as session:
        await session.begin()
        yield session
        await session.rollback()  # Rollback after each test — no leftover state

@pytest.fixture
async def client(db: AsyncSession) -> AsyncClient:
    async def override_get_db():
        yield db

    app.dependency_overrides[get_db_session] = override_get_db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac

    app.dependency_overrides.clear()
```

## Endpoint Tests

No `@pytest.mark.asyncio` needed with `asyncio_mode = "auto"`:

```python
async def test_create_user(client: AsyncClient):
    response = await client.post("/api/v1/users/", json={
        "email": "test@example.com",
        "username": "testuser",
        "password": "Test1234",
    })
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "test@example.com"
    assert "password" not in data

async def test_get_user_not_found(client: AsyncClient):
    response = await client.get("/api/v1/users/999")
    assert response.status_code == 404

async def test_list_users_requires_auth(client: AsyncClient):
    response = await client.get("/api/v1/users/")
    assert response.status_code == 401
```

## Auth Fixtures

```python
from app.core.security import hash_password, create_access_token
from app.models import User

@pytest.fixture
async def test_user(db: AsyncSession) -> User:
    user = User(
        email="auth@test.com",
        username="authuser",
        hashed_password=hash_password("Test1234"),
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user

@pytest.fixture
def auth_headers(test_user: User) -> dict:
    token = create_access_token(subject=str(test_user.id))
    return {"Authorization": f"Bearer {token}"}

async def test_protected_endpoint(client: AsyncClient, auth_headers: dict):
    response = await client.get("/api/v1/users/me", headers=auth_headers)
    assert response.status_code == 200

async def test_protected_endpoint_no_auth(client: AsyncClient):
    response = await client.get("/api/v1/users/me")
    assert response.status_code == 401
```

## Service Tests (No HTTP)

Test business logic directly against the DB session — faster and more isolated than HTTP tests:

```python
from app.users.service import create_user_db, get_user_db
from app.users.schemas import UserCreate
from sqlalchemy.exc import IntegrityError

async def test_create_user_service(db: AsyncSession):
    user_in = UserCreate(email="service@test.com", username="serviceuser", password="Test1234")
    user = await create_user_db(db, user_in)
    assert user.id is not None
    assert user.email == "service@test.com"

async def test_get_user_not_found(db: AsyncSession):
    user = await get_user_db(db, 999)
    assert user is None

async def test_duplicate_email_raises(db: AsyncSession):
    user_in = UserCreate(email="dup@test.com", username="user1", password="Test1234")
    await create_user_db(db, user_in)
    with pytest.raises(IntegrityError):
        user_in2 = UserCreate(email="dup@test.com", username="user2", password="Test1234")
        await create_user_db(db, user_in2)
```

## Mocking Async Dependencies

```python
from unittest.mock import AsyncMock, patch

async def test_with_mock_service(client: AsyncClient):
    mock_user = User(id=1, email="mock@test.com", username="mock")
    with patch("app.users.router.get_user_db", new_callable=AsyncMock) as mock:
        mock.return_value = mock_user
        response = await client.get("/api/v1/users/1")
        assert response.status_code == 200
        assert response.json()["email"] == "mock@test.com"
```

## Lifespan Events in Tests

`AsyncClient` does NOT trigger lifespan events by default. If you need them, use `asgi-lifespan`:

```python
# pip install asgi-lifespan
from asgi_lifespan import LifespanManager

@pytest.fixture
async def client_with_lifespan() -> AsyncClient:
    async with LifespanManager(app):
        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as ac:
            yield ac
```

## Quick Reference

| Component | Purpose |
|-----------|---------|
| `asyncio_mode = "auto"` in pyproject.toml | No `@pytest.mark.asyncio` needed |
| `NullPool` | Required for function-scoped async sessions |
| `await session.rollback()` in fixture | Test isolation — no leftover state |
| `ASGITransport(app=app)` | Test transport for `AsyncClient` |
| `app.dependency_overrides[get_db_session]` | Inject test DB session |
| `app.dependency_overrides.clear()` | Clean up after each test |
| `AsyncMock` | Mock async functions |
| `LifespanManager` (asgi-lifespan) | Trigger lifespan events in tests |
| `TestClient` | **Do not use in async tests** — blocks event loop |
