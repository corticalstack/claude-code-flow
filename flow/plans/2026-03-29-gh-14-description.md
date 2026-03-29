# Implementation Plan: GitHub Issue #14 — Merge Sort Algorithm

**Date:** 2026-03-29
**Issue:** [#14](https://github.com/jp/claude-code-flow/issues/14) — Test: Implement merge sort algorithm in Python with unit tests
**Branch:** `feature/14-merge-sort`
**Research:** [flow/research/2026-03-29-gh-14-description.md](../research/2026-03-29-gh-14-description.md)

---

## Overview

Implement a merge sort algorithm in Python with comprehensive unit tests. The goal is to produce code that passes ruff linting and mypy strict type checking, with all required test cases passing.

### Requirements Summary

- `src/algorithms/merge_sort.py` — merge sort implementation with Google-style docstring
- `tests/test_merge_sort.py` — pytest test suite with 7 test cases
- `src/algorithms/__init__.py` — package init (missing, must be created)
- All code passes `ruff check src/ tests/` and `mypy src/ tests/`

---

## Implementation Phases

### Phase 1: Package Structure

**Files to create:**
- `src/algorithms/__init__.py` — empty package init

**Why:** The `src/algorithms/` directory exists but has no `__init__.py`, so Python and mypy cannot resolve it as a package. This must exist before the module can be imported.

**Verification:** `python -c "import src.algorithms"` should not raise ImportError.

---

### Phase 2: Merge Sort Implementation

**File to create:** `src/algorithms/merge_sort.py`

**Design:**

```
def merge_sort(arr: list[int]) -> list[int]
    """Google-style docstring with description, args, returns, complexity."""
    # Base case: 0 or 1 elements → already sorted
    # Divide at midpoint
    # Recursively sort left and right halves
    # Merge sorted halves via _merge()

def _merge(left: list[int], right: list[int]) -> list[int]
    """Private helper: merge two sorted lists into one sorted list."""
    # Walk both lists with two pointers
    # Append remaining elements
```

**Key constraints:**
- Return a new list (no in-place mutation of input)
- Full type hints on both functions (mypy strict)
- Line length ≤ 88 chars (ruff)
- Module-level docstring

---

### Phase 3: Test Suite

**File to create:** `tests/test_merge_sort.py`

**Test cases:**

| Test name | Input | Expected output |
|---|---|---|
| `test_empty_list` | `[]` | `[]` |
| `test_single_element` | `[1]` | `[1]` |
| `test_already_sorted` | `[1, 2, 3]` | `[1, 2, 3]` |
| `test_reverse_sorted` | `[3, 2, 1]` | `[1, 2, 3]` |
| `test_duplicates` | `[3, 1, 2, 1]` | `[1, 1, 2, 3]` |
| `test_large_list` | `random.sample(range(-1000, 1000), 1000)` | `sorted(input)` |
| `test_negative_numbers` | `[-5, 3, -1, 0]` | `[-5, -1, 0, 3]` |

**Import:** `from src.algorithms.merge_sort import merge_sort`

---

## Files to Create/Modify

| Action | Path | Notes |
|---|---|---|
| Create | `src/algorithms/__init__.py` | Empty package init |
| Create | `src/algorithms/merge_sort.py` | Algorithm implementation |
| Create | `tests/test_merge_sort.py` | pytest test suite |

No existing files need to be modified.

---

## Success Criteria

All of the following must pass before the PR is submitted:

```bash
# Tests
pytest tests/test_merge_sort.py -v

# Linting
ruff check src/ tests/

# Type checking
mypy src/ tests/
```

Expected outcomes:
- `pytest`: 7 tests collected, all pass
- `ruff`: no issues reported
- `mypy`: `Success: no issues found`

---

## Notes

- `src/algorithms/__pycache__/merge_sort.cpython-312.pyc` exists — a prior compiled version is present, suggesting the algorithm was previously implemented. This does not affect our implementation.
- mypy strict mode requires explicit return types and no implicit `Any` on all functions including the private `_merge` helper.
- Use `uv run pytest` or activate `.venv` before running commands if the environment isn't already active.
