# Pagination

## Default: Cursor-Based

Cursor pagination uses an indexed `WHERE (created_at, id) < (:ts, :id)` lookup — O(log n) at any depth, consistent as data changes. Use it for all new collection endpoints.

Offset pagination (`LIMIT n OFFSET m`) requires the database to scan `m` rows — O(m) cost. Avoid for large or real-time datasets.

## FastAPI Query Model

```python
from typing import Annotated
from fastapi import Depends
from pydantic import BaseModel, ConfigDict, Field


class CursorParams(BaseModel):
    cursor: str | None = Field(None, description="Opaque cursor from previous response")
    limit: int = Field(20, ge=1, le=100)

    model_config = ConfigDict(extra="forbid")


CursorPagination = Annotated[CursorParams, Depends()]
```

```python
@router.get("/users")
async def list_users(
    pagination: CursorPagination,
    session: AsyncSession = Depends(get_session),
) -> UserListResponse:
    items, next_cursor = await paginate_users(session, pagination)
    return UserListResponse(
        data=items,
        pagination=PaginationMeta(next_cursor=next_cursor, has_more=next_cursor is not None),
    )
```

## Cursor Encoding

Clients treat cursors as opaque black boxes — never document their internal structure:

```python
import base64, json


def encode_cursor(item_id: str, sort_ts: str) -> str:
    payload = {"id": item_id, "ts": sort_ts}
    return base64.urlsafe_b64encode(json.dumps(payload).encode()).decode()


def decode_cursor(cursor: str) -> dict:
    return json.loads(base64.urlsafe_b64decode(cursor.encode()))
```

## SQLAlchemy Async Implementation

```python
from sqlalchemy import select, tuple_
from sqlalchemy.ext.asyncio import AsyncSession


async def paginate_users(
    session: AsyncSession,
    params: CursorParams,
) -> tuple[list[User], str | None]:
    fetch = params.limit + 1  # +1 to detect has_more

    stmt = select(User).order_by(User.created_at.desc(), User.id.desc()).limit(fetch)

    if params.cursor:
        decoded = decode_cursor(params.cursor)
        stmt = stmt.where(
            tuple_(User.created_at, User.id) < (decoded["ts"], decoded["id"])
        )

    rows = list((await session.execute(stmt)).scalars())
    has_more = len(rows) > params.limit
    items = rows[: params.limit]
    next_cursor = (
        encode_cursor(str(items[-1].id), items[-1].created_at.isoformat())
        if has_more
        else None
    )
    return items, next_cursor
```

**Always use a composite cursor on `(created_at, id)`** — timestamps can collide; the composite is always unique. `tuple_()` maps to a native SQL row-value comparison (`WHERE (col_a, col_b) < (:a, :b)`), which is efficient on PostgreSQL with a composite index.

## Response Envelope

```python
from pydantic import BaseModel


class PaginationMeta(BaseModel):
    next_cursor: str | None
    has_more: bool


class UserListResponse(BaseModel):
    data: list[UserResponse]
    pagination: PaginationMeta
```

```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6InV1aWQtYiIsInRzIjoiMjAyNi0wMS0xNVQxMDowMDowMFoifQ==",
    "has_more": true
  }
}
```

`has_more: false` with `next_cursor: null` signals the final page. Never run a `COUNT(*)` by default on unbounded tables.

## Sorting

The cursor must encode the same fields used for ordering. If clients can request `?sort=name`, include the sort key in the cursor payload so the next-page query uses the same ordering.

## When Offset Is Acceptable

- Small admin interfaces where "jump to page N" is required
- Report exports
- Datasets guaranteed to stay under ~10k rows and that change infrequently

```python
# Offset pattern for admin use cases
class OffsetParams(BaseModel):
    page: int = Field(1, ge=1)
    per_page: int = Field(20, ge=1, le=100)

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.per_page
```
