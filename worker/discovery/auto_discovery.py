"""Periodic auto-discovery of popular kids content via Piped API."""

import asyncio
import logging
import re
from datetime import UTC, date, datetime
from typing import Any

from clients.piped_client import PipedClient
from config import Settings

logger = logging.getLogger(__name__)

# Curated search queries rotated through discovery cycles
DISCOVERY_QUERIES = [
    # Toddler (1-3)
    ("nursery rhymes for toddlers", "toddler_music"),
    ("baby sensory videos", "toddler_sensory"),
    ("counting songs for babies", "toddler_educational"),
    # Preschool (3-5)
    ("educational cartoons for kids", "preschool_educational"),
    ("nature videos for preschoolers", "preschool_nature"),
    ("peppa pig full episodes", "preschool_cartoons"),
    # Early school (5-8)
    ("science experiments for kids", "school_science"),
    ("art tutorials for kids", "school_creative"),
    ("bluey full episodes", "school_cartoons"),
    # Older kids (8-12)
    ("science documentaries for kids", "older_science"),
    ("educational history for kids", "older_educational"),
    ("kids cooking shows", "older_creative"),
    # Shorts
    ("kids shorts funny", "shorts"),
    ("educational shorts for kids", "shorts_educational"),
]


DAILY_DISCOVERY_LIMIT = 250


class AutoDiscovery:
    """Periodically searches for popular kids content and queues for analysis."""

    def __init__(self, settings: Settings, supabase_client: Any, piped_client: PipedClient):
        self.settings = settings
        self.supabase = supabase_client
        self.piped = piped_client
        self._current_query_index = 0
        self._daily_count = 0
        self._daily_reset_date = date.today()

    def _check_daily_reset(self) -> None:
        """Reset the daily counter if the date has changed."""
        today = date.today()
        if today != self._daily_reset_date:
            logger.info(
                "Auto-discovery daily reset: %d videos discovered yesterday",
                self._daily_count,
            )
            self._daily_count = 0
            self._daily_reset_date = today

    @property
    def daily_remaining(self) -> int:
        self._check_daily_reset()
        return max(0, DAILY_DISCOVERY_LIMIT - self._daily_count)

    async def run_cycle(self) -> int:
        """Run one discovery cycle. Returns number of videos discovered."""
        self._check_daily_reset()
        if self._daily_count >= DAILY_DISCOVERY_LIMIT:
            logger.info(
                "Auto-discovery daily limit reached (%d/%d). Skipping cycle.",
                self._daily_count, DAILY_DISCOVERY_LIMIT,
            )
            return 0

        query, category = DISCOVERY_QUERIES[self._current_query_index]
        self._current_query_index = (
            self._current_query_index + 1
        ) % len(DISCOVERY_QUERIES)

        logger.info("Auto-discovery: searching '%s' (%s)", query, category)

        try:
            videos = await self.piped.search(query)
            count = await self._ingest_videos(videos, category)
            self._daily_count += count
            logger.info(
                "Auto-discovery: ingested %d videos for '%s' (%d/%d today)",
                count, query, self._daily_count, DAILY_DISCOVERY_LIMIT,
            )
            return count
        except Exception as e:
            logger.error("Auto-discovery failed for '%s': %s", query, e)
            return 0

    async def run_periodic(self, interval_hours: int = 6) -> None:
        """Run discovery cycles periodically."""
        while True:
            if self.daily_remaining > 0:
                # Run through 3 queries per cycle
                for _ in range(3):
                    if self.daily_remaining == 0:
                        break
                    await self.run_cycle()
                    await asyncio.sleep(5)  # Brief pause between queries

                logger.info(
                    "Auto-discovery cycle complete (%d/%d today). Next cycle in %dh.",
                    self._daily_count, DAILY_DISCOVERY_LIMIT, interval_hours,
                )
            else:
                logger.info(
                    "Auto-discovery daily limit reached (%d/%d). Next cycle in %dh.",
                    self._daily_count, DAILY_DISCOVERY_LIMIT, interval_hours,
                )

            await asyncio.sleep(interval_hours * 3600)

    async def _ingest_videos(
        self, videos: list[dict], category: str
    ) -> int:
        """Upsert videos into database and queue for analysis."""
        count = 0
        for item in videos:
            url = item.get("url", "")
            video_id = self._extract_video_id(url)
            if not video_id:
                continue

            title = item.get("title", "")
            duration = item.get("duration", 0)
            is_short = (
                0 < duration <= 60
                or "#shorts" in title.lower()
            )

            channel_id = self._extract_channel_id(
                item.get("uploaderUrl", "")
            )

            video_data = {
                "video_id": video_id,
                "title": title,
                "description": item.get("shortDescription", ""),
                "channel_id": channel_id,
                "thumbnail_url": item.get("thumbnail", ""),
                "duration_seconds": duration,
                "view_count": item.get("views", 0),
                "discovery_source": "auto_discovery",
                "is_short": is_short,
                "last_fetched_at": datetime.now(UTC).isoformat(),
            }

            try:
                # Upsert channel FIRST (yt_videos has FK to yt_channels)
                if channel_id:
                    self.supabase.table("yt_channels").upsert(
                        {
                            "channel_id": channel_id,
                            "title": item.get("uploaderName", ""),
                            "thumbnail_url": item.get("uploaderAvatar", ""),
                            "last_fetched_at": datetime.now(UTC).isoformat(),
                        },
                        on_conflict="channel_id",
                    ).execute()

                # Check if video already exists to avoid overwriting analysis_status
                existing_video = (
                    self.supabase.table("yt_videos")
                    .select("video_id")
                    .eq("video_id", video_id)
                    .maybe_single()
                    .execute()
                )
                if not existing_video.data:
                    video_data["analysis_status"] = "pending"

                self.supabase.table("yt_videos").upsert(
                    video_data, on_conflict="video_id"
                ).execute()

                # Queue for analysis only if not already queued/processing/completed
                existing_queue = (
                    self.supabase.table("analysis_queue")
                    .select("id")
                    .eq("video_id", video_id)
                    .in_("status", ["queued", "processing", "completed"])
                    .execute()
                )
                if not existing_queue.data:
                    self.supabase.table("analysis_queue").insert(
                        {
                            "video_id": video_id,
                            "priority": 8,
                            "source": "auto_discovery",
                        }
                    ).execute()

                count += 1
            except Exception as e:
                logger.warning("Failed to ingest %s: %s", video_id, e)

        return count

    @staticmethod
    def _extract_video_id(url: str) -> str | None:
        match = re.search(r"[?&]v=([a-zA-Z0-9_-]{11})", url)
        if match:
            return match.group(1)
        parts = url.rstrip("/").split("/")
        if parts:
            candidate = parts[-1]
            if re.fullmatch(r'[a-zA-Z0-9_-]{11}', candidate):
                return candidate
        return None

    @staticmethod
    def _extract_channel_id(url: str) -> str:
        return url.rstrip("/").split("/")[-1] if url else ""
