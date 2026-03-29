"""Word frequency counter utility."""

import re


def word_frequency(text: str) -> dict[str, int]:
    """Count the frequency of each word in a given string.

    Words are counted case-insensitively after stripping punctuation.

    Args:
        text: The input string to count words in.

    Returns:
        A dictionary mapping each word (lowercased) to its count.

    Example:
        >>> word_frequency("the cat sat on the mat")
        {'the': 2, 'cat': 1, 'sat': 1, 'on': 1, 'mat': 1}
        >>> word_frequency("Hello, world!")
        {'hello': 1, 'world': 1}
    """
    if not text:
        return {}

    words = re.findall(r"[a-zA-Z]+", text.lower())
    counts: dict[str, int] = {}
    for word in words:
        counts[word] = counts.get(word, 0) + 1
    return counts
