"""Simple in-memory rate limiter for FastAPI."""

import time
from collections import defaultdict

from fastapi import HTTPException, Request
from starlette.middleware.base import BaseHTTPMiddleware


class RateLimiter(BaseHTTPMiddleware):
    """Sliding window rate limiter.

    Limits requests per user (identified by Authorization header)
    to max_requests per window_seconds.
    """

    MAX_TRACKED_KEYS = 10_000

    def __init__(self, app, max_requests: int = 10, window_seconds: int = 60):
        super().__init__(app)
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._requests: dict[str, list[float]] = defaultdict(list)
        self._last_cleanup: float = time.time()
        self._cleanup_interval: float = 300  # 5 minutes

    async def dispatch(self, request: Request, call_next):
        # Skip rate limiting for health endpoint
        if request.url.path == "/api/health":
            return await call_next(request)

        # Identify user by auth header or IP
        user_key = request.headers.get("authorization", request.client.host)

        now = time.time()
        window_start = now - self.window_seconds

        # Clean old entries for current key
        self._requests[user_key] = [
            t for t in self._requests[user_key] if t > window_start
        ]

        # Periodic full cleanup of all keys
        if now - self._last_cleanup > self._cleanup_interval:
            self._full_cleanup(window_start)
            self._last_cleanup = now

        # Evict oldest keys if tracking too many
        if len(self._requests) > self.MAX_TRACKED_KEYS:
            self._evict_oldest()

        # Check limit
        if len(self._requests[user_key]) >= self.max_requests:
            raise HTTPException(
                status_code=429,
                detail=f"Rate limit exceeded. Max {self.max_requests} requests per {self.window_seconds}s.",
            )

        # Record request
        self._requests[user_key].append(now)

        return await call_next(request)

    def _full_cleanup(self, window_start: float) -> None:
        """Remove expired entries from all tracked keys."""
        keys_to_delete = []
        for key, timestamps in self._requests.items():
            active = [t for t in timestamps if t > window_start]
            if active:
                self._requests[key] = active
            else:
                keys_to_delete.append(key)
        for key in keys_to_delete:
            del self._requests[key]

    def _evict_oldest(self) -> None:
        """Evict the oldest 25% of tracked keys by most recent request time."""
        keys_by_recency = sorted(
            self._requests.keys(),
            key=lambda k: max(self._requests[k]) if self._requests[k] else 0,
        )
        evict_count = len(keys_by_recency) // 4
        for key in keys_by_recency[:evict_count]:
            del self._requests[key]
