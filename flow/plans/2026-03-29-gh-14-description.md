# Implementation Plan: GitHub Issue #14 — Implement Merge Sort Algorithm

**Date:** 2026-03-29
**Issue:** [#14](https://github.com/jparkypark/claude-code-flow/issues/14) — Test: Implement merge sort algorithm in Python with unit tests
**Research:** [flow/research/2026-03-29-gh-14-description.md](../research/2026-03-29-gh-14-description.md)
**Feature Branch:** `feature/14-merge-sort`

---

## Overview

Implement a merge sort algorithm in Python with comprehensive unit tests. This validates the Ralph autonomous workflow. The implementation follows divide-and-conquer: split input in half, recursively sort each half, merge sorted halves.

### Requirements Summary

- `src/algorithms/merge_sort.py` — implementation with `merge_sort(arr: list[int]) -> list[int]`
- `tests/test_merge_sort.py` — pytest suite covering 7 test cases
- Code quality: passes `ruff check` and `mypy` in strict mode
- New `src/algorithms/` package (directory + `__init__.py`)

---

## Implementation Phases

### Phase 1: Feature Branch Setup

**Goal:** Ensure work is on a feature branch, never on main.

**Steps:**
1. Check current branch: `git branch --show-current`
2. If on main, create feature branch: `git checkout -b feature/14-merge-sort`
3. Verify branch: `git branch --show-current` → must output `feature/14-merge-sort`

**Files modified:** none (git state only)

---

### Phase 2: Create `src/algorithms/` Package

**Goal:** Create the new package directory with empty `__init__.py`.

**Files to create:**
- `src/algorithms/__init__.py` — empty (matches style of `src/__init__.py`)

**Implementation:**

```python
# src/algorithms/__init__.py
# (empty)
```

---

### Phase 3: Implement `src/algorithms/merge_sort.py`

**Goal:** Implement merge sort with full type annotations and Google-style docstrings.

**Files to create:**
- `src/algorithms/merge_sort.py`

**Implementation:**

```python
"""Merge sort algorithm implementation."""


def _merge(left: list[int], right: list[int]) -> list[int]:
    """Merge two sorted lists into a single sorted list.

    Args:
        left: A sorted list of integers.
        right: A sorted list of integers.

    Returns:
        A new sorted list containing all elements from left and right.
    """
    result: list[int] = []
    i = 0
    j = 0
    while i < len(left) and j < len(right):
        if left[i] <= right[j]:
            result.append(left[i])
            i += 1
        else:
            result.append(right[j])
            j += 1
    result.extend(left[i:])
    result.extend(right[j:])
    return result


def merge_sort(arr: list[int]) -> list[int]:
    """Sort a list of integers using the merge sort algorithm.

    Uses a divide-and-conquer approach: recursively splits the input in half,
    sorts each half, then merges the sorted halves into a final sorted list.

    Args:
        arr: A list of integers to sort.

    Returns:
        A new sorted list containing all elements from arr in ascending order.
        The original list is not modified.

    Example:
        >>> merge_sort([3, 1, 2])
        [1, 2, 3]
        >>> merge_sort([])
        []

    Complexity:
        Time: O(n log n) — splits log n times, merges O(n) per level.
        Space: O(n) — new list created at each merge step.
    """
    if len(arr) <= 1:
        return list(arr)
    mid = len(arr) // 2
    left = merge_sort(arr[:mid])
    right = merge_sort(arr[mid:])
    return _merge(left, right)
```

**mypy strict compliance notes:**
- All parameters and return types annotated with `list[int]` (Python 3.12 style)
- No implicit `Any`
- No unused imports

---

### Phase 4: Create `tests/test_merge_sort.py`

**Goal:** Comprehensive pytest test suite covering all required cases.

**Files to create:**
- `tests/test_merge_sort.py`

**Implementation:**

```python
"""Tests for the merge sort algorithm."""

import random

from src.algorithms.merge_sort import merge_sort


def test_empty_list() -> None:
    assert merge_sort([]) == []


def test_single_element() -> None:
    assert merge_sort([1]) == [1]


def test_already_sorted() -> None:
    assert merge_sort([1, 2, 3]) == [1, 2, 3]


def test_reverse_sorted() -> None:
    assert merge_sort([3, 2, 1]) == [1, 2, 3]


def test_duplicates() -> None:
    assert merge_sort([3, 1, 2, 1]) == [1, 1, 2, 3]


def test_large_list() -> None:
    data = random.choices(range(-1000, 1000), k=1000)
    assert merge_sort(data) == sorted(data)


def test_negative_numbers() -> None:
    assert merge_sort([-5, 3, -1, 0]) == [-5, -1, 0, 3]
```

---

### Phase 5: Validation

**Goal:** Verify all acceptance criteria pass before committing.

**Commands to run:**

```bash
# Run tests
pytest tests/test_merge_sort.py -v

# Linting
ruff check src/ tests/

# Type checking
mypy src/ tests/
```

**Expected outcomes:**
- All 7 pytest tests pass
- `ruff check` exits with 0 (no issues)
- `mypy` exits with 0 (no type errors)

---

### Phase 6: Commit and PR

**Goal:** Create a clean commit and open a pull request.

**Steps:**
1. Stage new files: `git add src/algorithms/ tests/test_merge_sort.py`
2. Commit with descriptive message
3. Push feature branch: `git push -u origin feature/14-merge-sort`
4. Create PR referencing issue #14

---

## Success Criteria

| Criterion | Verification Command |
|-----------|---------------------|
| `src/algorithms/merge_sort.py` exists | `ls src/algorithms/merge_sort.py` |
| `src/algorithms/__init__.py` exists | `ls src/algorithms/__init__.py` |
| `tests/test_merge_sort.py` exists | `ls tests/test_merge_sort.py` |
| All 7 tests pass | `pytest tests/test_merge_sort.py -v` |
| Linting passes | `ruff check src/ tests/` |
| Type checking passes | `mypy src/ tests/` |
| Work is on feature branch | `git branch --show-current` → `feature/14-merge-sort` |

---

## Files to Create/Modify

| File | Action | Notes |
|------|--------|-------|
| `src/algorithms/__init__.py` | CREATE | Empty package init |
| `src/algorithms/merge_sort.py` | CREATE | Algorithm implementation |
| `tests/test_merge_sort.py` | CREATE | 7 pytest test cases |

No existing files are modified.
