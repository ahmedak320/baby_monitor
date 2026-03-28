"""Rate limiter for AI provider API calls to respect free tier limits.

Gemini Free Tier Limits (2026):
- 15 requests per minute
- 1,500 requests per day
- 1,000,000 tokens per minute

This module enforces per-minute and per-day request caps.
"""

import logging
import threading
import time
from collections import deque
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)

# Maximum time to block waiting for rate limit (5 minutes)
MAX_WAIT_SECONDS = 300


@dataclass
class ProviderRateLimiter:
    """Sliding-window rate limiter for API calls."""

    max_requests_per_minute: int = 10  # stay under 15 RPM limit
    max_requests_per_day: int = 1400  # stay under 1,500 RPD limit
    _minute_window: deque = field(default_factory=deque, repr=False)
    _day_window: deque = field(default_factory=deque, repr=False)
    _lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    def acquire(self) -> None:
        """Wait for a slot, then atomically reserve it. Thread-safe."""
        with self._lock:
            self._wait_if_needed()
            self.record_request()

    def wait_if_needed(self) -> None:
        """Block until a request can be made within rate limits."""
        self._wait_if_needed()

    def _wait_if_needed(self) -> None:
        """Internal wait logic (caller must hold lock if thread safety needed)."""
        while True:
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
                if wait_seconds > MAX_WAIT_SECONDS:
                    logger.error(
                        "Daily rate limit exhausted (%d/%d). "
                        "Would need to wait %.0fs — raising instead.",
                        len(self._day_window),
                        self.max_requests_per_day,
                        wait_seconds,
                    )
                    raise RuntimeError(
                        f"Daily API rate limit reached ({self.max_requests_per_day} RPD). "
                        "Try again later."
                    )
                logger.warning(
                    "Daily rate limit reached (%d/%d). Waiting %.0fs.",
                    len(self._day_window),
                    self.max_requests_per_day,
                    wait_seconds,
                )
                time.sleep(max(wait_seconds, 1))
                continue

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
                continue

            # Both limits OK — proceed
            return

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
        # Per-provider rate limit configs (RPM, RPD)
        configs = {
            "gemini": (10, 1400),           # Gemini free: 15 RPM / 1500 RPD
            "gemini_embedding": (10, 1400),  # Same Gemini free tier
            "claude": (50, 10000),
            "openai": (50, 10000),
        }
        rpm, rpd = configs.get(provider_name, (100, 100000))
        _limiters[provider_name] = ProviderRateLimiter(
            max_requests_per_minute=rpm,
            max_requests_per_day=rpd,
        )
    return _limiters[provider_name]
