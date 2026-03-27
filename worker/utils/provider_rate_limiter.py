"""Rate limiter for AI provider API calls to respect free tier limits.

Gemini Free Tier Limits (2026):
- 15 requests per minute
- 1,500 requests per day
- 1,000,000 tokens per minute

This module enforces per-minute and per-day request caps.
"""

import logging
import time
from collections import deque
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


@dataclass
class ProviderRateLimiter:
    """Sliding-window rate limiter for API calls."""

    max_requests_per_minute: int = 10  # stay under 15 RPM limit
    max_requests_per_day: int = 1400  # stay under 1,500 RPD limit
    _minute_window: deque = field(default_factory=deque, repr=False)
    _day_window: deque = field(default_factory=deque, repr=False)

    def wait_if_needed(self) -> None:
        """Block until a request can be made within rate limits."""
        now = time.time()

        # Clean expired entries
        minute_ago = now - 60
        day_ago = now - 86400
        while self._minute_window and self._minute_window[0] < minute_ago:
            self._minute_window.popleft()
        while self._day_window and self._day_window[0] < day_ago:
            self._day_window.popleft()

        # Check daily limit
        if len(self._day_window) >= self.max_requests_per_day:
            wait_seconds = self._day_window[0] - day_ago
            logger.warning(
                "Daily rate limit reached (%d/%d). Next slot in %.0f seconds.",
                len(self._day_window),
                self.max_requests_per_day,
                wait_seconds,
            )
            time.sleep(max(wait_seconds, 1))
            return self.wait_if_needed()

        # Check per-minute limit
        if len(self._minute_window) >= self.max_requests_per_minute:
            wait_seconds = self._minute_window[0] - minute_ago + 0.5
            logger.info(
                "Per-minute rate limit reached (%d/%d). Waiting %.1fs.",
                len(self._minute_window),
                self.max_requests_per_minute,
                wait_seconds,
            )
            time.sleep(max(wait_seconds, 0.5))
            return self.wait_if_needed()

    def record_request(self) -> None:
        """Record that a request was made."""
        now = time.time()
        self._minute_window.append(now)
        self._day_window.append(now)

    @property
    def remaining_today(self) -> int:
        """How many requests remain in the daily budget."""
        now = time.time()
        day_ago = now - 86400
        while self._day_window and self._day_window[0] < day_ago:
            self._day_window.popleft()
        return max(0, self.max_requests_per_day - len(self._day_window))


# Singleton instances per provider
_limiters: dict[str, ProviderRateLimiter] = {}


def get_rate_limiter(provider_name: str) -> ProviderRateLimiter:
    """Get or create a rate limiter for the given provider."""
    if provider_name not in _limiters:
        if provider_name == "gemini":
            _limiters[provider_name] = ProviderRateLimiter(
                max_requests_per_minute=10,  # Gemini free: 15 RPM, we use 10 for safety
                max_requests_per_day=1400,  # Gemini free: 1500 RPD, we use 1400 for safety
            )
        elif provider_name == "claude":
            _limiters[provider_name] = ProviderRateLimiter(
                max_requests_per_minute=50,
                max_requests_per_day=10000,
            )
        elif provider_name == "openai":
            _limiters[provider_name] = ProviderRateLimiter(
                max_requests_per_minute=50,
                max_requests_per_day=10000,
            )
        else:
            _limiters[provider_name] = ProviderRateLimiter(
                max_requests_per_minute=100,
                max_requests_per_day=100000,
            )
    return _limiters[provider_name]
