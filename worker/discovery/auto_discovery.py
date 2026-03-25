"""Periodic auto-discovery of popular kids content via Piped API."""

import asyncio
import logging
from datetime import datetime
from typing import Any

import httpx

from ..config import Settings

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


class AutoDiscovery:
    """Periodically searches for popular kids content and queues for analysis."""

    def __init__(self, settings: Settings, supabase_client: Any):
        self.settings = settings
        self.supabase = supabase_client
        self.piped_url = settings.piped_api_url
        self._current_query_index = 0

    async def run_cycle(self) -> int:
        """Run one discovery cycle. Returns number of videos discovered."""
        query, category = DISCOVERY_QUERIES[self._current_query_index]
        self._current_query_index = (
            self._current_query_index + 1
        ) % len(DISCOVERY_QUERIES)

        logger.info(f"Auto-discovery: searching '{query}' ({category})")

        try:
            videos = await self._search_piped(query)
            count = await self._ingest_videos(videos, category)
            logger.info(f"Auto-discovery: ingested {count} videos for '{query}'")
            return count
        except Exception as e:
            logger.error(f"Auto-discovery failed for '{query}': {e}")
            return 0

    async def run_periodic(self, interval_hours: int = 6) -> None:
        """Run discovery cycles periodically."""
        while True:
            # Run through 3 queries per cycle
            for _ in range(3):
                await self.run_cycle()
                await asyncio.sleep(5)  # Brief pause between queries

            logger.info(
                f"Auto-discovery cycle complete. "
                f"Next cycle in {interval_hours}h."
            )
            await asyncio.sleep(interval_hours * 3600)

    async def _search_piped(self, query: str) -> list[dict]:
        """Search Piped API for videos."""
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.piped_url}/search",
                params={"q": query, "filter": "videos"},
                timeout=15.0,
            )
            response.raise_for_status()
            data = response.json()
            items = data.get("items", [])
            return [
                item for item in items
                if item.get("type") == "stream"
            ]

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

            # Upsert video
            video_data = {
                "video_id": video_id,
                "title": title,
                "description": item.get("shortDescription", ""),
                "channel_id": self._extract_channel_id(
                    item.get("uploaderUrl", "")
                ),
                "thumbnail_url": item.get("thumbnail", ""),
                "duration_seconds": duration,
                "view_count": item.get("views", 0),
                "analysis_status": "pending",
                "discovery_source": "auto_discovery",
                "is_short": is_short,
            }

            try:
                self.supabase.table("yt_videos").upsert(
                    video_data, on_conflict="video_id"
                ).execute()

                # Upsert channel
                channel_id = video_data["channel_id"]
                if channel_id:
                    self.supabase.table("yt_channels").upsert(
                        {
                            "channel_id": channel_id,
                            "title": item.get("uploaderName", ""),
                        },
                        on_conflict="channel_id",
                    ).execute()

                # Queue for analysis (low priority)
                existing = (
                    self.supabase.table("analysis_queue")
                    .select("id")
                    .eq("video_id", video_id)
                    .in_("status", ["queued", "processing"])
                    .execute()
                )
                if not existing.data:
                    self.supabase.table("analysis_queue").insert(
                        {
                            "video_id": video_id,
                            "priority": 8,
                            "source": "auto_discovery",
                        }
                    ).execute()

                count += 1
            except Exception as e:
                logger.warning(f"Failed to ingest {video_id}: {e}")

        return count

    @staticmethod
    def _extract_video_id(url: str) -> str | None:
        import re
        match = re.search(r"[?&]v=([a-zA-Z0-9_-]{11})", url)
        if match:
            return match.group(1)
        parts = url.rstrip("/").split("/")
        if parts and len(parts[-1]) == 11:
            return parts[-1]
        return None

    @staticmethod
    def _extract_channel_id(url: str) -> str:
        return url.rstrip("/").split("/")[-1] if url else ""
