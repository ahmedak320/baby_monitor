"""Tests for the rate limiter middleware."""

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from api.rate_limiter import RateLimiter


def create_test_app(max_requests: int = 3, window_seconds: int = 60) -> FastAPI:
    app = FastAPI()
    app.add_middleware(RateLimiter, max_requests=max_requests, window_seconds=window_seconds)

    @app.get("/api/health")
    async def health():
        return {"status": "ok"}

    @app.get("/api/test")
    async def test_endpoint():
        return {"data": "ok"}

    return app


class TestRateLimiter:
    def test_allows_requests_within_limit(self):
        app = create_test_app(max_requests=3)
        client = TestClient(app)

        for _ in range(3):
            response = client.get("/api/test")
            assert response.status_code == 200

    def test_blocks_requests_over_limit(self):
        app = create_test_app(max_requests=2)
        client = TestClient(app)

        # First 2 should pass
        assert client.get("/api/test").status_code == 200
        assert client.get("/api/test").status_code == 200

        # Third should be rate limited
        response = client.get("/api/test")
        assert response.status_code == 429
        assert "Rate limit exceeded" in response.json()["detail"]

    def test_health_endpoint_bypasses_rate_limit(self):
        app = create_test_app(max_requests=1)
        client = TestClient(app)

        # Use up the limit
        assert client.get("/api/test").status_code == 200

        # Health should still work
        response = client.get("/api/health")
        assert response.status_code == 200
