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
