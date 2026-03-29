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
