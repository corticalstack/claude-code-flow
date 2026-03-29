"""Merge sort algorithm implementation."""


def merge_sort(arr: list[int]) -> list[int]:
    """Sort a list of integers using the merge sort algorithm.

    Uses a divide-and-conquer approach to recursively split the list
    into halves, sort each half, and merge them back together.

    Args:
        arr: A list of integers to sort.

    Returns:
        A new sorted list containing the same elements as arr.

    Example:
        >>> merge_sort([3, 1, 2])
        [1, 2, 3]
        >>> merge_sort([])
        []
        >>> merge_sort([-5, 3, -1, 0])
        [-5, -1, 0, 3]

    Time complexity: O(n log n) - divides list log n times, merges in O(n)
    Space complexity: O(n) - creates new lists during merge
    """
    if len(arr) <= 1:
        return list(arr)

    mid = len(arr) // 2
    left = merge_sort(arr[:mid])
    right = merge_sort(arr[mid:])
    return _merge(left, right)


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
