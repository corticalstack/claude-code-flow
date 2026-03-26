# Endpoints & Routing

## Router Setup

```python
from fastapi import APIRouter, Depends, HTTPException, status, Query, Path
from typing import Annotated

router = APIRouter(prefix="/users", tags=["users"])

# Define type aliases once — inject everywhere
DB = Annotated[AsyncSession, Depends(get_db_session)]
CurrentUser = Annotated[User, Depends(get_current_user)]
```

## Query Parameter Models (FastAPI 0.115+)

Group query parameters into a Pydantic model instead of individual function arguments.
`extra = "forbid"` rejects unknown query params with 422.

```python
from pydantic import BaseModel, ConfigDict
from fastapi import Query

class UserFilter(BaseModel):
    model_config = ConfigDict(extra="forbid")

    skip: int = Query(default=0, ge=0)
    limit: int = Query(default=20, ge=1, le=100)
    search: str | None = None
    is_active: bool | None = None
    role: UserRole | None = None

@router.get("/", response_model=list[UserOut])
async def list_users(db: DB, current_user: CurrentUser, filters: UserFilter = Query()) -> list[User]:
    return await get_users(db, **filters.model_dump(exclude_none=True))
```

The same pattern works for `Header()` and `Cookie()` parameter groups.

## CRUD Endpoints

```python
@router.post("/", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_user(db: DB, user_in: UserCreate) -> User:
    if await get_user_by_email(db, user_in.email):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Email already registered")
    return await create_user_db(db, user_in)

@router.get("/{user_id}", response_model=UserOut)
async def get_user(db: DB, user_id: Annotated[int, Path(gt=0)]) -> User:
    user = await get_user_db(db, user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")
    return user

@router.patch("/{user_id}", response_model=UserOut)
async def update_user(db: DB, user_id: int, user_in: UserUpdate, current_user: CurrentUser) -> User:
    if current_user.id != user_id and not current_user.is_admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not authorized")
    return await update_user_db(db, user_id, user_in)

@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(db: DB, user_id: int, current_user: CurrentUser) -> None:
    if not await delete_user_db(db, user_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")
```

## Custom Dependencies

```python
async def get_current_active_user(current_user: CurrentUser) -> User:
    if not current_user.is_active:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Inactive user")
    return current_user

ActiveUser = Annotated[User, Depends(get_current_active_user)]

async def require_admin(current_user: CurrentUser) -> User:
    if not current_user.is_admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Admin required")
    return current_user

AdminUser = Annotated[User, Depends(require_admin)]
```

**Dependency caching**: FastAPI caches dependency results within a single request. If `get_current_user`
is used in multiple chained dependencies for one route, it executes only once.

## Search / Advanced Query

```python
@router.get("/search", response_model=list[UserOut])
async def search_users(
    db: DB,
    q: str = Query(min_length=1, max_length=100),
    sort_by: Annotated[str, Query(pattern="^(name|email|created_at)$")] = "created_at",
    order: Annotated[str, Query(pattern="^(asc|desc)$")] = "desc",
) -> list[User]:
    return await search_users_db(db, q, sort_by, order)
```

## App Setup & Router Registration

```python
# app/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.api.v1.router import api_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialize shared resources
    yield
    # Shutdown: release resources

app = FastAPI(lifespan=lifespan)
app.include_router(api_router, prefix="/api/v1")

# app/api/v1/router.py
from fastapi import APIRouter
from app.users import router as users_router
from app.auth import router as auth_router

api_router = APIRouter()
api_router.include_router(users_router, prefix="/users")
api_router.include_router(auth_router, prefix="/auth")
```

## Response Model Options

```python
@router.get("/", response_model=list[UserOut], response_model_exclude_unset=True)
async def list_users(...) -> list[User]: ...

@router.get("/{id}", responses={
    200: {"model": UserOut},
    404: {"description": "User not found"},
})
async def get_user(...) -> User: ...
```

## Quick Reference

| Pattern | Purpose |
|---------|---------|
| `UserFilter = BaseModel` + `= Query()` | Group query params (0.115+) |
| `Annotated[T, Depends()]` type alias | Clean dependency injection |
| `Path(gt=0)` | Validated path parameter |
| `Query(ge=0, le=100)` | Validated query parameter |
| `response_model=Model` | Response serialization schema |
| `status_code=201` on `@router.post` | Correct HTTP status |
| `HTTPException(status, detail)` | Error responses |
| `response_model_exclude_unset=True` | Omit unset fields from response |
