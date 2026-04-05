"""Multi-source auto-discovery of kids content.

Discovery sources (in priority order):
1. YouTube RSS feeds — free, reliable, monitors curated channels
2. Invidious API search — free, richer search than Piped
3. Piped API — fallback search when Invidious is down
"""

import asyncio
import logging
import re
from datetime import UTC, date, datetime
from typing import Any

from clients.invidious_client import InvidiousClient
from clients.piped_client import PipedClient
from clients.rss_client import RSSClient
from config import Settings

logger = logging.getLogger(__name__)

# Curated kids channels to monitor via RSS (channel_id, name)
CURATED_CHANNELS = [
    # Toddler / Nursery
    ("UCbCmjCuTUZos6Inko4u57UQ", "CoComelon"),
    ("UC-SJ6nODDmufqBzPBwCvYvQ", "Peppa Pig"),
    ("UC_x5XG1OV2P6uZZ5FSM9Ttw", "Google for Developers"),  # placeholder
    ("UCkQO3QsgTpNTsOw6ujimT5Q", "Baby Shark - Pinkfong"),
    ("UCo8bcnLyZH8tBIH9V1mLgqQ", "Bluey"),
    ("UClLqfRJVkBGBnMIuR0kWlOg", "Super Simple Songs"),
    ("UC4NALVCmcmL5ntpV0thoH6w", "Little Baby Bum"),
    ("UCGwu0nbY2wSkW8N-cghnLpA", "Blippi"),
    ("UCF3_S8E9PTdYHkhBjRNkyfQ", "Kids Diana Show"),
    # Educational
    ("UCD4EOyXKjfDUhCI6jlOZZYQ", "SciShow Kids"),
    ("UCvW8JzztV3k3W8tohjSNRlw", "Nat Geo Kids"),
    ("UC295-Dw_tDNtZXFeAPAQKEw", "The Dr. Binocs Show"),
    # Creative
    ("UCWOA1ZGiwLbDQJk2xCDBnQQ", "Art for Kids Hub"),
    # Songs & Learning
    ("UCLsooMJoIpl_7ux2jvdPB-Q", "Bounce Patrol"),
    ("UCRx3mKNUdl8QE06nEug7p6Q", "Dave and Ava"),
]

# Search queries for Invidious/Piped (discovering NEW channels/content)
DISCOVERY_QUERIES = [
    ("nursery rhymes for toddlers", "toddler_music"),
    ("baby sensory videos", "toddler_sensory"),
    ("counting songs for babies", "toddler_educational"),
    ("educational cartoons for kids", "preschool_educational"),
    ("nature videos for preschoolers", "preschool_nature"),
    ("peppa pig full episodes", "preschool_cartoons"),
    ("science experiments for kids", "school_science"),
    ("art tutorials for kids", "school_creative"),
    ("bluey full episodes", "school_cartoons"),
    ("science documentaries for kids", "older_science"),
    ("educational history for kids", "older_educational"),
    ("kids cooking shows", "older_creative"),
    ("kids shorts funny", "shorts"),
    ("educational shorts for kids", "shorts_educational"),
]

DAILY_DISCOVERY_LIMIT = 250


class AutoDiscovery:
    """Multi-source content discovery for the analysis pipeline."""

    def __init__(
        self,
        settings: Settings,
        supabase_client: Any,
        piped_client: PipedClient,
    ):
        self.settings = settings
        self.supabase = supabase_client
        self.piped = piped_client
        self._rss = RSSClient()
        self._invidious = InvidiousClient()
        self._current_query_index = 0
        self._daily_count = 0
        self._daily_reset_date = date.today()

    def _check_daily_reset(self) -> None:
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

    # -- RSS-based discovery (curated channels) ----------------------------

    async def _discover_from_rss(self) -> int:
        """Poll curated channels via YouTube RSS feeds."""
        channel_ids = [cid for cid, _ in CURATED_CHANNELS]
        logger.info("RSS discovery: polling %d curated channels", len(channel_ids))

        videos = await self._rss.get_multiple_channels(channel_ids)
        if not videos:
            logger.warning("RSS discovery: no videos returned from any channel")
            return 0

        count = 0
        for v in videos:
            if self.daily_remaining == 0:
                break
            video_id = v.get("video_id", "")
            if not video_id or not re.fullmatch(r"[a-zA-Z0-9_-]{11}", video_id):
                continue

            ingested = await self._ingest_one(
                video_id=video_id,
                title=v.get("title", ""),
                description=v.get("description", ""),
                channel_id=v.get("channel_id", ""),
                channel_title=v.get("channel_title", ""),
                thumbnail_url=v.get("thumbnail_url", ""),
                duration_seconds=0,  # RSS doesn't provide duration
                view_count=0,
                source="rss_discovery",
            )
            if ingested:
                count += 1
                self._daily_count += 1

        logger.info("RSS discovery: ingested %d new videos", count)
        return count

    # -- Search-based discovery (Invidious → Piped fallback) ---------------

    async def _discover_from_search(self) -> int:
        """Search for kids content via Invidious, falling back to Piped."""
        query, category = DISCOVERY_QUERIES[self._current_query_index]
        self._current_query_index = (
            self._current_query_index + 1
        ) % len(DISCOVERY_QUERIES)

        logger.info("Search discovery: '%s' (%s)", query, category)

        # Try Invidious first, then Piped
        videos: list[dict] = []
        source = "invidious_discovery"
        try:
            results = await self._invidious.search(query)
            videos = self._normalize_invidious(results)
        except Exception as e:
            logger.warning("Invidious search failed, trying Piped: %s", e)
            source = "piped_discovery"
            try:
                results = await self.piped.search(query)
                videos = self._normalize_piped(results)
            except Exception as e2:
                logger.error("All search sources failed for '%s': %s", query, e2)
                return 0

        count = 0
        for v in videos:
            if self.daily_remaining == 0:
                break
            ingested = await self._ingest_one(source=source, **v)
            if ingested:
                count += 1
                self._daily_count += 1

        logger.info(
            "Search discovery: ingested %d videos for '%s' via %s",
            count, query, source,
        )
        return count

    # -- Main cycle --------------------------------------------------------

    async def run_cycle(self) -> int:
        """Run one discovery cycle: RSS first, then one search query."""
        self._check_daily_reset()
        if self._daily_count >= DAILY_DISCOVERY_LIMIT:
            logger.info("Auto-discovery daily limit reached (%d/%d).", self._daily_count, DAILY_DISCOVERY_LIMIT)
            return 0

        total = 0

        # Phase 1: RSS feeds from curated channels
        total += await self._discover_from_rss()
        await asyncio.sleep(2)

        # Phase 2: One search query via Invidious/Piped
        if self.daily_remaining > 0:
            total += await self._discover_from_search()

        return total

    async def run_periodic(self, interval_hours: int = 6) -> None:
        """Run discovery cycles periodically."""
        while True:
            if self.daily_remaining > 0:
                count = await self.run_cycle()
                logger.info(
                    "Auto-discovery cycle complete: %d new (%d/%d today). Next in %dh.",
                    count, self._daily_count, DAILY_DISCOVERY_LIMIT, interval_hours,
                )
            else:
                logger.info(
                    "Auto-discovery daily limit reached (%d/%d). Next in %dh.",
                    self._daily_count, DAILY_DISCOVERY_LIMIT, interval_hours,
                )
            await asyncio.sleep(interval_hours * 3600)

    # -- Normalization helpers ---------------------------------------------

    @staticmethod
    def _normalize_invidious(results: list[dict]) -> list[dict]:
        """Normalize Invidious API results to common format."""
        out = []
        for item in results:
            vid = item.get("videoId", "")
            if not vid:
                continue
            out.append({
                "video_id": vid,
                "title": item.get("title", ""),
                "description": item.get("description", "")[:2000],
                "channel_id": item.get("authorId", ""),
                "channel_title": item.get("author", ""),
                "thumbnail_url": (
                    item["videoThumbnails"][0]["url"]
                    if item.get("videoThumbnails")
                    else ""
                ),
                "duration_seconds": item.get("lengthSeconds", 0),
                "view_count": item.get("viewCount", 0),
            })
        return out

    @staticmethod
    def _normalize_piped(results: list[dict]) -> list[dict]:
        """Normalize Piped API results to common format."""
        out = []
        for item in results:
            url = item.get("url", "")
            match = re.search(r"[?&]v=([a-zA-Z0-9_-]{11})", url)
            if not match:
                parts = url.rstrip("/").split("/")
                vid = parts[-1] if parts and re.fullmatch(r"[a-zA-Z0-9_-]{11}", parts[-1]) else ""
            else:
                vid = match.group(1)
            if not vid:
                continue

            uploader_url = item.get("uploaderUrl", "")
            channel_id = uploader_url.rstrip("/").split("/")[-1] if uploader_url else ""

            out.append({
                "video_id": vid,
                "title": item.get("title", ""),
                "description": item.get("shortDescription", "")[:2000],
                "channel_id": channel_id,
                "channel_title": item.get("uploaderName", ""),
                "thumbnail_url": item.get("thumbnail", ""),
                "duration_seconds": item.get("duration", 0),
                "view_count": item.get("views", 0),
            })
        return out

    # -- Ingestion ---------------------------------------------------------

    async def _ingest_one(
        self,
        video_id: str,
        title: str = "",
        description: str = "",
        channel_id: str = "",
        channel_title: str = "",
        thumbnail_url: str = "",
        duration_seconds: int = 0,
        view_count: int = 0,
        source: str = "auto_discovery",
    ) -> bool:
        """Upsert a single video + channel and queue for analysis.

        Returns True if the video was newly ingested.
        """
        if not re.fullmatch(r"[a-zA-Z0-9_-]{11}", video_id):
            return False

        is_short = (
            0 < duration_seconds <= 60
            or "#shorts" in title.lower()
        )

        try:
            # Upsert channel first (FK constraint)
            if channel_id:
                self.supabase.table("yt_channels").upsert(
                    {
                        "channel_id": channel_id,
                        "title": channel_title,
                        "last_fetched_at": datetime.now(UTC).isoformat(),
                    },
                    on_conflict="channel_id",
                ).execute()

            # Check if video already exists to avoid overwriting analysis_status
            existing = (
                self.supabase.table("yt_videos")
                .select("video_id")
                .eq("video_id", video_id)
                .limit(1)
                .execute()
            )

            video_data: dict[str, Any] = {
                "video_id": video_id,
                "title": title,
                "description": description,
                "channel_id": channel_id,
                "thumbnail_url": thumbnail_url,
                "duration_seconds": duration_seconds,
                "view_count": view_count,
                "discovery_source": source,
                "is_short": is_short,
                "last_fetched_at": datetime.now(UTC).isoformat(),
            }
            if not existing.data:
                video_data["analysis_status"] = "pending"

            self.supabase.table("yt_videos").upsert(
                video_data, on_conflict="video_id"
            ).execute()

            # Queue for analysis if not already queued/processing/completed
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
                        "source": source,
                    }
                ).execute()

            return True
        except Exception as e:
            logger.warning("Failed to ingest %s: %s", video_id, e)
            return False
