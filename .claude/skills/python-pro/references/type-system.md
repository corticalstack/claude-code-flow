# Type System Mastery

## Basic Type Annotations

```python
from typing import Any
from collections.abc import Sequence, Mapping

# Function signatures
def process_user(name: str, age: int, active: bool = True) -> dict[str, Any]:
    return {"name": name, "age": age, "active": active}

# Use | for unions (Python 3.10+)
def find_user(user_id: int | str) -> dict[str, Any] | None:
    if isinstance(user_id, int):
        return {"id": user_id}
    return None

# Collections - prefer collections.abc for parameters
def process_items(items: Sequence[str]) -> list[str]:
    """Accepts list, tuple, or any sequence."""
    return [item.upper() for item in items]

def merge_configs(base: Mapping[str, int], override: dict[str, int]) -> dict[str, int]:
    """Mapping for read-only, dict for mutable."""
    return {**base, **override}
```

## PEP 695 — New Generics Syntax (Python 3.12+)

**Use this syntax for all new code.** `TypeVar` + `Generic` is now legacy.

```python
# Generic function — no TypeVar import needed
def first[T](items: Sequence[T]) -> T | None:
    return items[0] if items else None

# Generic class
class Cache[K, V]:
    def __init__(self) -> None:
        self._data: dict[K, V] = {}

    def get(self, key: K) -> V | None:
        return self._data.get(key)

    def set(self, key: K, value: V) -> None:
        self._data[key] = value

# Bounded TypeVar — only accepts subtypes of the bound
def inspect[S: str](text: S) -> S:
    return text

# Constrained TypeVar — only accepts exact listed types
def concat[T: (str, bytes)](a: T, b: T) -> T:
    return a + b

# Type alias — use `type` statement, not TypeAlias
type JsonDict = dict[str, Any]
type UserId = int | str
type Ordered[T] = list[T] | tuple[T, ...]

# Result type using PEP 695
from dataclasses import dataclass

@dataclass
class Success[T]:
    value: T

@dataclass
class Failure:
    message: str

type Result[T] = Success[T] | Failure

def divide(a: int, b: int) -> Result[float]:
    if b == 0:
        return Failure("Division by zero")
    return Success(a / b)
```

## Legacy Generics — What NOT to Write

```python
# ❌ OUTDATED — do not write this in new code
from typing import TypeVar, Generic, TypeAlias, Optional, Union, List, Dict

T = TypeVar("T")
K = TypeVar("K")
V = TypeVar("V")

class Cache(Generic[K, V]): ...          # ❌ use class Cache[K, V]
def first(items: List[T]) -> Optional[T]: ...  # ❌ use list[T] and T | None
JsonDict: TypeAlias = dict[str, Any]     # ❌ use `type JsonDict = dict[str, Any]`
x: Union[int, str] = 1                  # ❌ use int | str
y: Optional[str] = None                 # ❌ use str | None

# ✅ Modern equivalents
class Cache[K, V]: ...
def first[T](items: list[T]) -> T | None: ...
type JsonDict = dict[str, Any]
x: int | str = 1
y: str | None = None
```

## Protocol for Structural Typing

```python
from typing import Protocol, runtime_checkable

# Define interface without inheritance
class Drawable(Protocol):
    def draw(self) -> str: ...

    @property
    def color(self) -> str: ...

class Circle:
    def __init__(self, radius: float, color: str) -> None:
        self.radius = radius
        self._color = color

    def draw(self) -> str:
        return f"Drawing {self._color} circle"

    @property
    def color(self) -> str:
        return self._color

# Circle satisfies Drawable without inheriting from it
def render(shape: Drawable) -> str:
    return shape.draw()

# Runtime checkable protocol
@runtime_checkable
class Closeable(Protocol):
    def close(self) -> None: ...

def cleanup(resource: Closeable) -> None:
    if isinstance(resource, Closeable):
        resource.close()
```

## Special Forms

```python
from typing import (
    Literal, TypedDict, NotRequired, ReadOnly,
    Self, Never, LiteralString, TypeIs, overload, override, Final
)

# Literal types for constants
type Mode = Literal["read", "write", "append"]

def open_file(path: str, mode: Mode) -> None: ...

# TypedDict for structured dicts
class UserDict(TypedDict):
    id: ReadOnly[int]        # 3.13+: field cannot be mutated
    name: str
    email: str
    age: NotRequired[int]    # Optional field

# Self for method chaining and subclass-aware return types
class Builder:
    def __init__(self) -> None:
        self._value = 0

    def add(self, n: int) -> Self:
        self._value += n
        return self

    def multiply(self, n: int) -> Self:
        self._value *= n
        return self

# Never — function that never returns (raises or loops forever)
def fail(msg: str) -> Never:
    raise RuntimeError(msg)

# LiteralString — injection-safe string (only accepts literals, not runtime strings)
import sqlite3

def query(conn: sqlite3.Connection, sql: LiteralString) -> list[Any]:
    return conn.execute(sql).fetchall()

# @override — documents intent and lets type checkers catch rename bugs
class Base:
    def process(self, data: str) -> str:
        return data

class Child(Base):
    @override
    def process(self, data: str) -> str:  # type checker errors if Base.process disappears
        return data.upper()

# Overload for different signatures
@overload
def coerce(data: str) -> str: ...

@overload
def coerce(data: int) -> int: ...

def coerce(data: str | int) -> str | int:
    if isinstance(data, str):
        return data.upper()
    return data * 2

# @deprecated (Python 3.13+)
from warnings import deprecated

@deprecated("Use new_api() instead")
def old_api() -> None: ...
```

## Type Narrowing

```python
from typing import assert_never, TypeIs

def process_value(value: int | str | None) -> str:
    if value is None:
        return "null"
    if isinstance(value, int):
        return str(value * 2)
    return value.upper()  # narrowed to str

# Exhaustiveness checking with assert_never
def handle_mode(mode: Literal["read", "write"]) -> str:
    if mode == "read":
        return "Reading"
    elif mode == "write":
        return "Writing"
    else:
        assert_never(mode)  # type error if a new Literal value is added without handling it

# TypeIs — prefer over TypeGuard for standard narrowing (Python 3.13+)
# TypeIs narrows in BOTH the if and else branch (like isinstance)
def is_str(x: object) -> TypeIs[str]:
    return isinstance(x, str)

def process(x: str | int) -> None:
    if is_str(x):
        reveal_type(x)   # str
    else:
        reveal_type(x)   # int  ← TypeGuard cannot narrow the else branch

# Use TypeGuard only for structurally incompatible narrowing
# e.g., list[object] → list[str] (TypeIs would be unsafe here)
from typing import TypeGuard

def is_str_list(val: list[object]) -> TypeGuard[list[str]]:
    return all(isinstance(x, str) for x in val)
```

## Callable Types

```python
from collections.abc import Callable
from typing import ParamSpec, Concatenate

P = ParamSpec("P")

# Basic callable
def apply(func: Callable[[int, int], int], a: int, b: int) -> int:
    return func(a, b)

# ParamSpec for decorators that preserve full call signatures
def logging_decorator[R](func: Callable[P, R]) -> Callable[P, R]:
    from functools import wraps

    @wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        print(f"Calling {func.__name__}")
        return func(*args, **kwargs)
    return wrapper

# Concatenate for dependency injection patterns
def with_connection[R](
    func: Callable[Concatenate[Connection, P], R]
) -> Callable[P, R]:
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        conn = get_connection()
        return func(conn, *args, **kwargs)
    return wrapper
```

## Mypy Configuration

```toml
# pyproject.toml
[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_any_generics = true
disallow_subclassing_any = true
disallow_untyped_calls = true
disallow_incomplete_defs = true
check_untyped_defs = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
warn_no_return = true
warn_unreachable = true
strict_equality = true

[[tool.mypy.overrides]]
module = "third_party.*"
ignore_missing_imports = true
```

## Common Pitfalls

```python
# ❌ typing.ByteString — removed in Python 3.14
# Use: bytes | bytearray | memoryview

# ❌ datetime.utcnow() — deprecated, returns naive datetime
import datetime
ts = datetime.datetime.utcnow()         # ❌

# ✅ Always use timezone-aware datetimes
ts = datetime.datetime.now(tz=datetime.UTC)  # ✅

# ❌ Type comments (Python 2 relic)
x = []  # type: List[int]              # ❌

# ✅ Inline annotations
x: list[int] = []                      # ✅

# ❌ from __future__ import annotations with Pydantic v2
# This defers annotation evaluation and breaks Pydantic's runtime introspection.
# Use PEP 695 `type` aliases and native 3.12+ syntax instead.
```
