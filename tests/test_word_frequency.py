"""Tests for the word_frequency function."""

from src.utils.word_frequency import word_frequency


def test_empty_string() -> None:
    assert word_frequency("") == {}


def test_single_word() -> None:
    assert word_frequency("hello") == {"hello": 1}


def test_multiple_words() -> None:
    assert word_frequency("the cat sat on the mat") == {
        "the": 2,
        "cat": 1,
        "sat": 1,
        "on": 1,
        "mat": 1,
    }


def test_mixed_case() -> None:
    assert word_frequency("Hello hello HELLO") == {"hello": 3}


def test_with_punctuation() -> None:
    assert word_frequency("Hello, world!") == {"hello": 1, "world": 1}
