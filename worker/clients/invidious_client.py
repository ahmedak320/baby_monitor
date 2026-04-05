"""Invidious API client with multi-instance failover."""

import logging
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx

logger = logging.getLogger(__name__)

# Public Invidious API instances sorted by reliability
DEFAULT_INSTANCES = [
    "https://inv.nadeko.net",
    "https://invidious.nerdvpn.de",
    "https://yewtu.be",
]


class InvidiousClient:
    """Invidious API client with instance failover."""

    def __init__(self, instances: list[str] | None = None, timeout: float = 15.0):
        self._instances = instances or DEFAULT_INSTANCES
        self._timeout = timeout
        self._unhealthy: dict[str, datetime] = {}
        self._cooldown = timedelta(minutes=10)

    async def search(self, query: str, sort_by: str = "relevance") -> list[dict]:
        """Search for videos. Returns list of video dicts."""
        data = await self._request(
            "/api/v1/search",
            params={"q": query, "type": "video", "sort_by": sort_by},
        )
        if isinstance(data, list):
            return [item for item in data if item.get("type") == "video"]
        return []

    async def trending(self, region: str = "US", content_type: str = "") -> list[dict]:
        """Get trending videos."""
        params: dict[str, str] = {"region": region}
        if content_type:
            params["type"] = content_type
        data = await self._request("/api/v1/trending", params=params)
        return data if isinstance(data, list) else []

    async def _request(
        self, path: str, params: dict[str, Any] | None = None
    ) -> Any:
        """Try each healthy instance until one succeeds."""
        now = datetime.now(UTC)
        errors: list[str] = []

        for instance in self._instances:
            # Skip unhealthy instances still in cooldown
            unhealthy_since = self._unhealthy.get(instance)
            if unhealthy_since and now - unhealthy_since < self._cooldown:
                continue

            try:
                async with httpx.AsyncClient() as client:
                    resp = await client.get(
                        f"{instance}{path}",
                        params=params,
                        timeout=self._timeout,
                        follow_redirects=True,
                    )
                    resp.raise_for_status()
                    self._unhealthy.pop(instance, None)
                    return resp.json()
            except Exception as e:
                self._unhealthy[instance] = now
                errors.append(f"{instance}: {e}")
                logger.warning("Invidious %s failed: %s", instance, e)

        raise ConnectionError(
            f"All Invidious instances failed: {'; '.join(errors)}"
        )
