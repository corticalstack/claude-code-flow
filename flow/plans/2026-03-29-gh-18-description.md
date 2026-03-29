# Implementation Plan: GitHub Issue #18 — Python Fibonacci Sequence Generator

## Overview

Implement a Python Fibonacci sequence generator as a utility module, following existing patterns in the codebase. This is a test issue for validating the Ralph autonomous workflow.

**Issue:** #18 — Test: Implement a Python Fibonacci sequence generator
**Branch:** `feature/18-fibonacci-generator`

## Requirements

- `src/utils/fibonacci.py` with `def fibonacci(n: int) -> list[int]`
- Returns first `n` Fibonacci numbers starting at 0
- Raises `ValueError` for negative input
- Google-style docstring, type hints, ruff + mypy clean
- `tests/test_fibonacci.py` with 5 pytest test cases

## Files to Create

| File | Action |
|------|--------|
| `src/utils/fibonacci.py` | Create — implementation |
| `tests/test_fibonacci.py` | Create — pytest test suite |

## Files to NOT Create (already exist)

- `src/__init__.py`
- `src/utils/__init__.py`
- `tests/__init__.py`
- `pyproject.toml`

## Implementation Phases

### Phase 1: Implementation (`src/utils/fibonacci.py`)

Create the module with an iterative implementation:

```python
"""Fibonacci sequence generator utility."""


def fibonacci(n: int) -> list[int]:
    """Generate the first n Fibonacci numbers.

    Args:
        n: The number of Fibonacci numbers to generate. Must be non-negative.

    Returns:
        A list containing the first n Fibonacci numbers, starting with 0.

    Raises:
        ValueError: If n is negative.

    Example:
        >>> fibonacci(10)
        [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
    """
    if n < 0:
        raise ValueError(f"n must be non-negative, got {n}")
    result: list[int] = []
    a, b = 0, 1
    for _ in range(n):
        result.append(a)
        a, b = b, a + b
    return result
```

**Design decisions:**
- Iterative (not recursive) — avoids stack overflow, simpler for mypy
- `list[int]` annotation satisfies mypy strict mode
- `ValueError` with descriptive message

### Phase 2: Tests (`tests/test_fibonacci.py`)

Create pytest test file mirroring `tests/test_word_frequency.py` structure:

```python
"""Tests for the fibonacci module."""

import pytest

from src.utils.fibonacci import fibonacci


def test_zero_terms() -> None:
    assert fibonacci(0) == []


def test_one_term() -> None:
    assert fibonacci(1) == [0]


def test_two_terms() -> None:
    assert fibonacci(2) == [0, 1]


def test_ten_terms() -> None:
    assert fibonacci(10) == [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]


def test_negative_raises_value_error() -> None:
    with pytest.raises(ValueError):
        fibonacci(-1)
```

### Phase 3: Verification

Run quality checks in order:

```bash
pytest tests/test_fibonacci.py -v
ruff check src/ tests/
mypy src/ tests/
```

All must pass before committing.

## Success Criteria

- [x] `src/utils/fibonacci.py` exists with `fibonacci()` function
- [x] `pytest tests/test_fibonacci.py -v` — all 5 tests pass
- [x] `ruff check src/ tests/` — no errors
- [x] `mypy src/ tests/` — no errors
- [x] Negative input raises `ValueError`

## Style Reference

Follow `src/utils/word_frequency.py` as the style template:
- Same module-level docstring pattern
- Same Google-style function docstring (Args, Returns, Raises, Example)
- Same test import path: `from src.utils.fibonacci import fibonacci`
- Plain `def test_*` functions, no fixtures needed for pure functions
