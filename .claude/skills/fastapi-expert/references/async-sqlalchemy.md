# Async SQLAlchemy 2.0+

## Engine & Session Manager

Use a `DatabaseSessionManager` class for clean lifecycle management. `expire_on_commit=False`
is critical in async — it prevents lazy-load errors after a commit.

```python
import contextlib
from typing import AsyncIterator, Annotated
from sqlalchemy.ext.asyncio import (
    create_async_engine, AsyncSession, async_sessionmaker, AsyncAttrs
)
from sqlalchemy.orm import DeclarativeBase
from fastapi import Depends

# AsyncAttrs enables awaitable relationship access via `.awaitable_attrs`
class Base(AsyncAttrs, DeclarativeBase):
    pass

class DatabaseSessionManager:
    def __init__(self, database_url: str) -> None:
        self._engine = create_async_engine(
            database_url,
            pool_size=10,
            max_overflow=20,
            pool_pre_ping=True,    # Detect stale connections
            pool_recycle=3600,     # Recycle hourly
            echo=False,
        )
        self._sessionmaker = async_sessionmaker(
            bind=self._engine,
            autocommit=False,
            autoflush=False,
            expire_on_commit=False,
        )

    async def close(self) -> None:
        await self._engine.dispose()

    @contextlib.asynccontextmanager
    async def session(self) -> AsyncIterator[AsyncSession]:
        session = self._sessionmaker()
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

# Module-level singleton
sessionmanager = DatabaseSessionManager(settings.DATABASE_URL)

async def get_db_session() -> AsyncIterator[AsyncSession]:
    async with sessionmanager.session() as session:
        yield session

DB = Annotated[AsyncSession, Depends(get_db_session)]
```

## Lifespan Handler

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    async with sessionmanager._engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Shutdown
    await sessionmanager.close()

app = FastAPI(lifespan=lifespan)
```

## Model Definition

Use `mapped_column()` with `Mapped[]` — provides full type checking. Avoid legacy `Column()`.

Set `lazy="raise"` on relationships to prevent accidental lazy loading (which fails silently in async).

```python
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, ForeignKey, DateTime, func
from datetime import datetime

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    username: Mapped[str] = mapped_column(String(128), index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(default=True)
    bio: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    # lazy="raise" prevents accidental lazy loading in async context
    posts: Mapped[list["Post"]] = relationship(
        back_populates="author",
        lazy="raise",
    )

class Post(Base):
    __tablename__ = "posts"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    content: Mapped[str]
    author_id: Mapped[int] = mapped_column(ForeignKey("users.id"))

    author: Mapped["User"] = relationship(back_populates="posts", lazy="raise")
```

## CRUD Operations

Commit at the route handler level, not inside service/CRUD functions — keeps services composable.

```python
from sqlalchemy import select, update, delete
from sqlalchemy.orm import selectinload, joinedload

async def get_user(db: AsyncSession, user_id: int) -> User | None:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()

# selectinload: separate SELECT IN query — preferred for collections
async def get_user_with_posts(db: AsyncSession, user_id: int) -> User | None:
    result = await db.execute(
        select(User)
        .options(selectinload(User.posts))
        .where(User.id == user_id)
    )
    return result.scalar_one_or_none()

async def get_users(db: AsyncSession, skip: int = 0, limit: int = 100) -> list[User]:
    result = await db.execute(select(User).offset(skip).limit(limit))
    return list(result.scalars().all())

async def create_user(db: AsyncSession, user_in: UserCreate) -> User:
    user = User(**user_in.model_dump())
    db.add(user)
    await db.flush()      # Assigns ID without committing
    await db.refresh(user)
    return user
    # Caller (route handler) calls await db.commit()

async def update_user(db: AsyncSession, user_id: int, user_in: UserUpdate) -> User | None:
    await db.execute(
        update(User)
        .where(User.id == user_id)
        .values(**user_in.model_dump(exclude_unset=True))
    )
    return await get_user(db, user_id)

async def delete_user(db: AsyncSession, user_id: int) -> bool:
    result = await db.execute(delete(User).where(User.id == user_id))
    return result.rowcount > 0
```

## AsyncAttrs — Ad-hoc Relationship Access

When a model inherits `AsyncAttrs`, you can await relationships without explicit eager loading:

```python
# Requires Base to inherit AsyncAttrs
user = await get_user(db, user_id)
posts = await user.awaitable_attrs.posts  # Issues SELECT automatically
```

## Quick Reference

| Operation | Pattern |
|-----------|---------|
| Select one | `result.scalar_one_or_none()` |
| Select many | `result.scalars().all()` |
| Eager load collection | `.options(selectinload(Model.rel))` |
| Eager load single | `.options(joinedload(Model.rel))` |
| Ad-hoc relationship | `await obj.awaitable_attrs.rel` (needs `AsyncAttrs`) |
| Create | `db.add(obj)` → `await db.flush()` → `await db.refresh(obj)` |
| Update | `update(Model).where(...).values(...)` |
| Delete | `delete(Model).where(...)` |
| Commit | `await db.commit()` — in route handler, not service |
| Rollback | `await db.rollback()` — done automatically by session manager |
