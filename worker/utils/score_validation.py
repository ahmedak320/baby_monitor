"""Validation helpers for AI provider response scores."""

import math


def strip_json_fences(text: str) -> str:
    """Remove markdown code fences from a JSON response.

    AI providers sometimes wrap JSON in ```json ... ``` blocks.
    """
    text = text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return text


def safe_float(value, default: float = 1.0, min_val: float = 0.0, max_val: float = 10.0) -> float:
    """Clamp a score to a valid range, rejecting NaN/Infinity.

    Args:
        value: The raw value from an AI provider response.
        default: Fallback value if the input is invalid.
        min_val: Minimum allowed value (inclusive).
        max_val: Maximum allowed value (inclusive).

    Returns:
        A float clamped to [min_val, max_val], or default if invalid.
    """
    try:
        f = float(value)
        if math.isnan(f) or math.isinf(f):
            return default
        return max(min_val, min(max_val, f))
    except (TypeError, ValueError):
        return default


def safe_int(value, default: int = 0, min_val: int = 0, max_val: int = 18) -> int:
    """Clamp an integer score to a valid range, rejecting NaN/Infinity.

    Args:
        value: The raw value from an AI provider response.
        default: Fallback value if the input is invalid.
        min_val: Minimum allowed value (inclusive).
        max_val: Maximum allowed value (inclusive).

    Returns:
        An int clamped to [min_val, max_val], or default if invalid.
    """
    try:
        f = float(value)
        if math.isnan(f) or math.isinf(f):
            return default
        return max(min_val, min(max_val, int(f)))
    except (TypeError, ValueError):
        return default
