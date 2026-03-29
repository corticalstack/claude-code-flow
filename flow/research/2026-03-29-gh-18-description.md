# Research: GitHub Issue #18 — Python Fibonacci Sequence Generator

## Issue Summary

**Title:** Test: Implement a Python Fibonacci sequence generator
**Labels:** `enhancement`, `research-in-progress`, `ralph-test`
**Purpose:** Test issue for validating the Ralph autonomous workflow (generated code will be discarded after validation).

## Requirements

### Files to Create
- `src/utils/fibonacci.py` — main implementation
- `tests/test_fibonacci.py` — pytest test suite

### Function Signature
```python
def fibonacci(n: int) -> list[int]:
```

### Behavior
- Returns the first `n` Fibonacci numbers as a list
- `fibonacci(0)` → `[]`
- `fibonacci(1)` → `[0]`
- `fibonacci(2)` → `[0, 1]`
- `fibonacci(10)` → `[0, 1, 1, 2, 3, 5, 8, 13, 21, 34]`
- Raises `ValueError` if `n` is negative

### Documentation
- Google-style docstring with description, Args, Returns, and Example sections

### Code Quality
- Type hints on all functions
- `ruff check` passes
- `mypy` type checking passes

## Existing Codebase State

### Installed Tooling (`.venv/`)
- Python 3.12
- `pytest 9.0.2`
- `ruff 0.15.8`
- `mypy 1.19.1`

### Existing Python Files (patterns to follow)
- `src/utils/word_frequency.py` — closest analogue; single-function utility module with Google-style docstring, type hints, no external dependencies
- `tests/test_word_frequency.py` — pytest test file; direct imports from `src.utils.*`, plain `def test_*` functions, no fixtures needed for pure functions
- `src/utils/__init__.py` — already exists (empty package init)
- `tests/__init__.py` — already exists

### What Does NOT Need to be Created
- `src/__init__.py` — already exists
- `src/utils/__init__.py` — already exists
- `tests/__init__.py` — already exists
- `pyproject.toml` — already exists (created for prior issues)

## Architecture Notes

### Module Structure
```
src/
  utils/
    fibonacci.py      ← new
tests/
  test_fibonacci.py   ← new
```

### fibonacci.py Design
Simple iterative implementation — no external dependencies needed:
```python
def fibonacci(n: int) -> list[int]:
    if n < 0:
        raise ValueError(...)
    result: list[int] = []
    a, b = 0, 1
    for _ in range(n):
        result.append(a)
        a, b = b, a + b
    return result
```

### Key Implementation Decisions
- **Iterative, not recursive** — avoids stack overflow for large `n`, simpler to type-check
- **No external dependencies** — pure stdlib
- **`ValueError` for negative input** — matches issue requirement; include helpful message
- **Sequence starts at 0** — confirmed by test cases: `[0, 1, 1, 2, 3, 5, ...]`

## Test Cases Required

| Input | Expected Output |
|-------|----------------|
| `0`   | `[]`           |
| `1`   | `[0]`          |
| `2`   | `[0, 1]`       |
| `10`  | `[0, 1, 1, 2, 3, 5, 8, 13, 21, 34]` |
| `-1`  | raises `ValueError` |

## Acceptance Criteria Checklist

- [ ] `src/utils/fibonacci.py` exists with `fibonacci()` function
- [ ] `pytest tests/test_fibonacci.py -v` — all 5 test cases pass
- [ ] `ruff check src/ tests/` passes
- [ ] `mypy src/ tests/` passes
- [ ] Negative input raises `ValueError`

## Implementation Considerations

1. **Follow `word_frequency.py` as the style template** — same module, same docstring style, same test structure
2. **mypy strict** — `pyproject.toml` likely has `strict = true`; the iterative approach with explicit `list[int]` annotation will satisfy mypy cleanly
3. **No `__all__` needed** — existing utils don't use it
4. **Test file import path**: `from src.utils.fibonacci import fibonacci` (mirrors word_frequency test)
