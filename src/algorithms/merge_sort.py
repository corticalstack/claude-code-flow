"""Merge sort algorithm implementation."""


def merge_sort(arr: list[int]) -> list[int]:
    """Sort a list of integers using the merge sort algorithm.

    Args:
        arr: The list of integers to sort.

    Returns:
        A new sorted list containing the same elements as arr.

    Complexity:
        Time: O(n log n) in all cases.
        Space: O(n) auxiliary space.
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
