"""Track YouTube API quota usage."""

import logging
from datetime import date

logger = logging.getLogger(__name__)

# YouTube API v3 daily quota limit
DAILY_QUOTA_LIMIT = 10_000

# Quota costs per operation
QUOTA_COSTS = {
    "search.list": 100,
    "videos.list": 1,
    "channels.list": 1,
    "playlistItems.list": 1,
    "captions.list": 50,
}


class QuotaTracker:
    """Track daily YouTube API quota usage."""

    def __init__(self) -> None:
        self._used = 0
        self._date = date.today()

    def _reset_if_new_day(self) -> None:
        today = date.today()
        if today != self._date:
            logger.info("New day, resetting quota. Yesterday used: %d", self._used)
            self._used = 0
            self._date = today

    def use(self, operation: str, count: int = 1) -> bool:
        """Record quota usage. Returns False if quota would be exceeded."""
        self._reset_if_new_day()
        cost = QUOTA_COSTS.get(operation, 1) * count
        if self._used + cost > DAILY_QUOTA_LIMIT:
            logger.warning("Quota would be exceeded: used=%d, cost=%d", self._used, cost)
            return False
        self._used += cost
        return True

    @property
    def remaining(self) -> int:
        self._reset_if_new_day()
        return DAILY_QUOTA_LIMIT - self._used

    @property
    def is_exhausted(self) -> bool:
        return self.remaining <= 0
