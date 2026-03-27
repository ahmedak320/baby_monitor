"""Priority scoring for analysis queue items."""


def calculate_priority(
    demand_count: int,
    channel_trust_score: float,
    is_premium_request: bool,
    hours_since_published: float,
) -> int:
    """Calculate priority score for a video analysis job.

    Lower number = higher priority (1 is highest, 10 is lowest).
    """
    score = 5  # base priority

    # More parents requesting = higher priority
    if demand_count >= 10:
        score -= 2
    elif demand_count >= 3:
        score -= 1

    # Premium users get priority
    if is_premium_request:
        score -= 1

    # Newer content gets slight boost
    if hours_since_published < 24:
        score -= 1

    # Trusted channels are lower priority (likely to pass)
    if channel_trust_score > 0.8:
        score += 1

    return max(1, min(10, score))
