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
    random.seed(42)
    arr = [random.randint(-1000, 1000) for _ in range(1000)]
    result = merge_sort(arr)
    assert result == sorted(arr)
    assert len(result) == 1000


def test_negative_numbers() -> None:
    assert merge_sort([-5, 3, -1, 0]) == [-5, -1, 0, 3]


def test_returns_new_list() -> None:
    arr = [3, 1, 2]
    result = merge_sort(arr)
    assert result is not arr
    assert arr == [3, 1, 2]
