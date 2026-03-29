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
