"""Multi-instance Piped API client with health-checked failover."""

import ipaddress
import logging
import socket
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any
from urllib.parse import urlparse

import httpx

logger = logging.getLogger(__name__)


@dataclass
class InstanceHealth:
    """Health state for a single Piped instance."""

    url: str
    is_healthy: bool = True
    last_failure: datetime | None = None
    last_health_check: datetime | None = None
    consecutive_failures: int = 0


@dataclass
class PipedClient:
    """Piped API client that cycles through multiple instances with failover.

    On failure, marks an instance unhealthy for `unhealthy_cooldown` and
    tries the next healthy instance.  After `circuit_threshold` consecutive
    failures across ALL instances, stops trying for `circuit_cooldown`.
    """

    instances: list[str] = field(default_factory=lambda: ["https://pipedapi.kavin.rocks"])
    timeout: float = 15.0
    unhealthy_cooldown: timedelta = field(default_factory=lambda: timedelta(minutes=5))
    circuit_threshold: int = 3
    circuit_cooldown: timedelta = field(default_factory=lambda: timedelta(minutes=15))

    # Internal state (not constructor args)
    _health: dict[str, InstanceHealth] = field(default=None, init=False, repr=False)
    _current_index: int = field(default=0, init=False, repr=False)
    _total_consecutive_failures: int = field(default=0, init=False, repr=False)
    _circuit_open_until: datetime | None = field(default=None, init=False, repr=False)

    def __post_init__(self) -> None:
        self._health = {url: InstanceHealth(url=url) for url in self.instances}

    # -- Public API ----------------------------------------------------------

    async def search(self, query: str, filter: str = "videos") -> list[dict]:
        """Search for videos across instances."""
        data = await self._execute_with_failover(
            "/search", params={"q": query, "filter": filter}
        )
        items = data.get("items", [])
        return [item for item in items if item.get("type") == "stream"]

    async def get_video(self, video_id: str) -> dict:
        """Get video details by ID."""
        return await self._execute_with_failover(f"/streams/{video_id}")

    async def get_channel(self, channel_id: str) -> dict:
        """Get channel info by ID."""
        return await self._execute_with_failover(f"/channel/{channel_id}")

    async def get_channel_videos(self, channel_id: str) -> list[dict]:
        """Get recent videos from a channel."""
        data = await self._execute_with_failover(f"/channel/{channel_id}")
        return data.get("relatedStreams", [])

    async def get_trending(self, region: str = "US") -> list[dict]:
        """Get trending videos."""
        return await self._execute_with_failover(
            "/trending", params={"region": region}
        )

    async def health_check(self) -> dict[str, bool]:
        """Check health of all instances. Returns {url: is_healthy}."""
        results: dict[str, bool] = {}
        async with httpx.AsyncClient() as client:
            for url in self.instances:
                try:
                    self._validate_url(url)
                    response = await client.get(
                        f"{url}/trending",
                        params={"region": "US"},
                        timeout=5.0,
                    )
                    healthy = response.status_code == 200
                except Exception:
                    healthy = False

                health = self._health[url]
                health.is_healthy = healthy
                health.last_health_check = datetime.now(UTC)
                if healthy:
                    health.consecutive_failures = 0
                results[url] = healthy

        logger.info(
            "Piped health check: %d/%d healthy",
            sum(results.values()),
            len(results),
        )
        return results

    # -- Internal -------------------------------------------------------------

    async def _execute_with_failover(
        self, path: str, params: dict[str, Any] | None = None
    ) -> Any:
        """Try each healthy instance in round-robin order."""
        if self._is_circuit_open():
            raise PipedAllInstancesDownError(
                "Piped circuit breaker open — all instances recently failed"
            )

        tried = 0
        last_error: Exception | None = None

        for _ in range(len(self.instances)):
            instance_url = self._get_next_instance()
            if instance_url is None:
                break
            tried += 1

            try:
                self._validate_url(instance_url)
                async with httpx.AsyncClient() as client:
                    response = await client.get(
                        f"{instance_url}{path}",
                        params=params,
                        timeout=self.timeout,
                    )
                    response.raise_for_status()
                    data = response.json()

                # Success — reset counters.
                self._mark_healthy(instance_url)
                self._total_consecutive_failures = 0
                return data

            except Exception as e:
                logger.warning(
                    "Piped instance %s failed for %s: %s",
                    instance_url, path, e,
                )
                self._mark_unhealthy(instance_url)
                last_error = e

        # All instances failed.
        self._total_consecutive_failures += 1
        if self._total_consecutive_failures >= self.circuit_threshold:
            self._circuit_open_until = datetime.now(UTC) + self.circuit_cooldown
            logger.error(
                "Piped circuit breaker tripped after %d consecutive full failures",
                self._total_consecutive_failures,
            )

        raise PipedAllInstancesDownError(
            f"All {tried} Piped instances failed for {path}"
        ) from last_error

    def _get_next_instance(self) -> str | None:
        """Get the next healthy (or cooldown-expired) instance, round-robin."""
        now = datetime.now(UTC)
        for _ in range(len(self.instances)):
            url = self.instances[self._current_index]
            self._current_index = (self._current_index + 1) % len(self.instances)

            health = self._health[url]
            if health.is_healthy:
                return url
            # Check cooldown expiry.
            if (
                health.last_failure
                and now - health.last_failure >= self.unhealthy_cooldown
            ):
                logger.debug("Piped instance %s cooldown expired, retrying", url)
                return url

        return None

    def _mark_healthy(self, url: str) -> None:
        health = self._health[url]
        health.is_healthy = True
        health.consecutive_failures = 0

    def _mark_unhealthy(self, url: str) -> None:
        health = self._health[url]
        health.is_healthy = False
        health.last_failure = datetime.now(UTC)
        health.consecutive_failures += 1

    def _is_circuit_open(self) -> bool:
        if self._circuit_open_until is None:
            return False
        if datetime.now(UTC) >= self._circuit_open_until:
            # Cooldown elapsed — allow a probe cycle.
            self._circuit_open_until = None
            self._total_consecutive_failures = 0
            return False
        return True

    @staticmethod
    def _validate_url(url: str) -> None:
        """Validate that a URL is safe (not pointing to private/loopback IPs)."""
        parsed = urlparse(url)
        if parsed.scheme not in ("http", "https"):
            raise ValueError(f"Invalid URL scheme: {parsed.scheme}")
        if not parsed.hostname:
            raise ValueError("URL has no hostname")
        try:
            addr_infos = socket.getaddrinfo(parsed.hostname, None)
        except socket.gaierror as e:
            raise ValueError(f"Cannot resolve hostname: {parsed.hostname}") from e
        for addr_info in addr_infos:
            ip = ipaddress.ip_address(addr_info[4][0])
            if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved:
                raise ValueError(f"URL resolves to non-public IP: {ip}")


class PipedAllInstancesDownError(Exception):
    """All Piped instances are unavailable."""
