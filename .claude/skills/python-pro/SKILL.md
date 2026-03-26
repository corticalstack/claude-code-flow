---
name: python-pro
description: Use when building Python applications requiring type safety, async programming, or robust error handling. Invoke for type hints, PEP 695 generics, async/await with TaskGroup, dataclasses, Pydantic v2, uv packaging, and structured error handling.
license: MIT
metadata:
  author: https://github.com/corticalstack
  version: "1.0.0"
  domain: language
  triggers: Python, type hints, type annotations, async Python, asyncio, TaskGroup, pytest, mypy, dataclasses, Pydantic v2, uv, ruff, PEP 695, generics, Protocol, TypedDict, TypeIs, error handling, context managers, pathlib, Python best practices
  role: specialist
  scope: implementation
  output-format: code
  related-skills: fastapi-expert
---

# Python Pro

Modern Python 3.12+ specialist focused on type-safe, async-first, production-ready code.

## When to Use This Skill

- Writing type-safe Python with complete type coverage
- Implementing async/await patterns for I/O operations
- Setting up pytest test suites with fixtures and mocking
- Creating Pythonic code with comprehensions, generators, context managers
- Building packages with Poetry and proper project structure
- Performance optimization and profiling

## Core Workflow

1. **Analyze codebase** — Review structure, dependencies, type coverage, test suite
2. **Design interfaces** — Define protocols, dataclasses, type aliases
3. **Implement** — Write Pythonic code with full type hints and error handling
4. **Test** — Create comprehensive pytest suite with >90% coverage
5. **Validate** — Run `mypy --strict`, `ruff check`, `ruff format`
   - If mypy fails: fix type errors reported and re-run before proceeding
   - If tests fail: debug assertions, update fixtures, and iterate until green
   - If ruff reports issues: apply auto-fixes (`ruff check --fix`, `ruff format`), then re-validate

## Reference Guide

Load detailed guidance based on context:

| Topic | Reference | Load When |
|-------|-----------|-----------|
| Type System | `references/type-system.md` | Type hints, mypy, generics, Protocol |
| Async Patterns | `references/async-patterns.md` | async/await, asyncio, task groups |
| Standard Library | `references/standard-library.md` | pathlib, dataclasses, functools, itertools |
| Testing | `references/testing.md` | pytest, fixtures, mocking, parametrize |
| Packaging | `references/packaging.md` | poetry, pip, pyproject.toml, distribution |

## Constraints

### MUST DO
- Type hints for all function signatures and class attributes
- PEP 695 generics syntax: `class Foo[T]`, `def func[T]()`, `type Alias = ...`
- `X | None` instead of `Optional[X]`; `X | Y` instead of `Union[X, Y]`
- `asyncio.TaskGroup` for concurrent tasks; `asyncio.timeout()` for timeouts
- `datetime.now(tz=datetime.UTC)` — never `datetime.utcnow()` (deprecated)
- `@override` on methods that intentionally override a parent method
- `asyncio.run(main())` as the sole async entry point
- PEP 8 compliance via `ruff format`; linting via `ruff check`
- Comprehensive docstrings (Google style)
- Test coverage exceeding 90% with pytest (`asyncio_mode = "auto"`)
- Dataclasses for internal structures; Pydantic v2 at trust boundaries (API I/O, config)
- Context managers for resource handling; `pathlib.Path` over `os.path`

### MUST NOT DO
- Use `TypeVar` + `Generic` for new generic classes/functions (use PEP 695 syntax)
- Use `typing.Optional`, `typing.Union`, `typing.List`, `typing.Dict` (use builtins + `|`)
- Use `TypeAlias` (use `type` statement)
- Skip type annotations on public APIs
- Use `asyncio.gather()` for structured concurrency (use `TaskGroup`)
- Use `asyncio.wait_for()` (use `asyncio.timeout()`)
- Use `asyncio.get_event_loop()` or event loop policies (deprecated, removal 3.16)
- Use `asyncio.iscoroutinefunction()` (use `inspect.iscoroutinefunction()`)
- Use `datetime.utcnow()` (deprecated — use `datetime.now(tz=datetime.UTC)`)
- Use removed 3.13 modules: `cgi`, `aifc`, `crypt`, `telnetlib`, etc.
- Use `from __future__ import annotations` with Pydantic v2 (breaks runtime introspection)
- Use mutable default arguments
- Use bare except clauses
- Hardcode secrets or configuration

## Code Examples

### Type-annotated function with error handling
```python
from pathlib import Path

def read_config(path: Path) -> dict[str, str]:
    """Read configuration from a file.

    Args:
        path: Path to the configuration file.

    Returns:
        Parsed key-value configuration entries.

    Raises:
        FileNotFoundError: If the config file does not exist.
        ValueError: If a line cannot be parsed.
    """
    config: dict[str, str] = {}
    with path.open() as f:
        for line in f:
            key, _, value = line.partition("=")
            if not key.strip():
                raise ValueError(f"Invalid config line: {line!r}")
            config[key.strip()] = value.strip()
    return config
```

### Dataclass with validation
```python
from dataclasses import dataclass, field

@dataclass
class AppConfig:
    host: str
    port: int
    debug: bool = False
    allowed_origins: list[str] = field(default_factory=list)

    def __post_init__(self) -> None:
        if not (1 <= self.port <= 65535):
            raise ValueError(f"Invalid port: {self.port}")
```

### Async pattern
```python
import asyncio
import httpx

async def fetch_all(urls: list[str]) -> list[bytes]:
    """Fetch multiple URLs concurrently."""
    async with httpx.AsyncClient() as client:
        tasks = [client.get(url) for url in urls]
        responses = await asyncio.gather(*tasks)
        return [r.content for r in responses]
```

### pytest fixture and parametrize
```python
import pytest
from pathlib import Path

@pytest.fixture
def config_file(tmp_path: Path) -> Path:
    cfg = tmp_path / "config.txt"
    cfg.write_text("host=localhost\nport=8080\n")
    return cfg

@pytest.mark.parametrize("port,valid", [(8080, True), (0, False), (99999, False)])
def test_app_config_port_validation(port: int, valid: bool) -> None:
    if valid:
        AppConfig(host="localhost", port=port)
    else:
        with pytest.raises(ValueError):
            AppConfig(host="localhost", port=port)
```

### PEP 695 generics (Python 3.12+)
```python
# Generic function — no TypeVar import needed
def first[T](items: list[T]) -> T | None:
    return items[0] if items else None

# Generic class
class Cache[K, V]:
    def __init__(self) -> None:
        self._data: dict[K, V] = {}

    def get(self, key: K) -> V | None:
        return self._data.get(key)

# Type alias
type JsonDict = dict[str, object]
```

### mypy strict + ruff configuration (pyproject.toml)
```toml
[tool.mypy]
python_version = "3.12"
strict = true

[tool.ruff]
line-length = 88
target-version = "py312"

[tool.ruff.lint]
select = ["E", "W", "F", "I", "UP", "B", "C4", "SIM", "TC", "PTH", "RUF"]
ignore = ["E501"]
```

Clean `mypy --strict` output looks like:
```
Success: no issues found in 12 source files
```
Any reported error must be resolved before the implementation is considered complete.

## Output Templates

When implementing Python features, provide:
1. Module file with complete type hints
2. Test file with pytest fixtures
3. Type checking confirmation (mypy --strict passes)
4. Brief explanation of Pythonic patterns used

## Knowledge Reference

Python 3.12+, PEP 695 generics, mypy strict, pytest asyncio_mode=auto, ruff (lint+format), uv, dataclasses, Pydantic v2, asyncio.TaskGroup, asyncio.timeout, pathlib, functools, itertools, contextlib, collections.abc, Protocol, TypeIs, TypedDict, copy.replace
