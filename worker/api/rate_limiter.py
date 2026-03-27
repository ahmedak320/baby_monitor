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

    def __init__(self, app, max_requests: int = 10, window_seconds: int = 60):
        super().__init__(app)
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._requests: dict[str, list[float]] = defaultdict(list)

    async def dispatch(self, request: Request, call_next):
        # Skip rate limiting for health endpoint
        if request.url.path == "/api/health":
            return await call_next(request)

        # Identify user by auth header or IP
        user_key = request.headers.get("authorization", request.client.host)

        now = time.time()
        window_start = now - self.window_seconds

        # Clean old entries
        self._requests[user_key] = [
            t for t in self._requests[user_key] if t > window_start
        ]

        # Check limit
        if len(self._requests[user_key]) >= self.max_requests:
            raise HTTPException(
                status_code=429,
                detail=f"Rate limit exceeded. Max {self.max_requests} requests per {self.window_seconds}s.",
            )

        # Record request
        self._requests[user_key].append(now)

        return await call_next(request)
