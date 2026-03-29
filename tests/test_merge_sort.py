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
