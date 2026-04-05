"""YouTube RSS feed client for monitoring channel uploads."""

import logging
import xml.etree.ElementTree as ET
from typing import Any

import httpx

logger = logging.getLogger(__name__)

YOUTUBE_RSS_URL = "https://www.youtube.com/feeds/videos.xml"


class RSSClient:
    """Fetch recent videos from YouTube channel RSS feeds.

    YouTube RSS feeds are free, require no API key, and return
    the 15 most recent uploads per channel.
    """

    def __init__(self, timeout: float = 10.0):
        self._timeout = timeout

    async def get_channel_videos(self, channel_id: str) -> list[dict]:
        """Fetch recent videos from a channel's RSS feed.

        Returns list of dicts with: video_id, title, channel_id,
        channel_title, published, thumbnail_url, description.
        """
        url = f"{YOUTUBE_RSS_URL}?channel_id={channel_id}"
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(url, timeout=self._timeout)
                resp.raise_for_status()
                return self._parse_feed(resp.text, channel_id)
        except Exception as e:
            logger.warning("RSS fetch failed for %s: %s", channel_id, e)
            return []

    async def get_multiple_channels(
        self, channel_ids: list[str]
    ) -> list[dict]:
        """Fetch videos from multiple channels concurrently."""
        import asyncio

        tasks = [self.get_channel_videos(cid) for cid in channel_ids]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        videos: list[dict] = []
        for cid, result in zip(channel_ids, results):
            if isinstance(result, Exception):
                logger.warning("RSS failed for %s: %s", cid, result)
            elif isinstance(result, list):
                videos.extend(result)
        return videos

    def _parse_feed(self, xml_text: str, channel_id: str) -> list[dict]:
        """Parse YouTube RSS/Atom feed XML into video dicts."""
        ns = {
            "atom": "http://www.w3.org/2005/Atom",
            "yt": "http://www.youtube.com/xml/schemas/2015",
            "media": "http://search.yahoo.com/mrss/",
        }

        try:
            root = ET.fromstring(xml_text)
        except ET.ParseError as e:
            logger.error("RSS XML parse error for %s: %s", channel_id, e)
            return []

        # Get channel title from feed
        channel_title = ""
        title_el = root.find("atom:title", ns)
        if title_el is not None and title_el.text:
            channel_title = title_el.text

        videos: list[dict] = []
        for entry in root.findall("atom:entry", ns):
            video_id_el = entry.find("yt:videoId", ns)
            title_el = entry.find("atom:title", ns)
            published_el = entry.find("atom:published", ns)

            if video_id_el is None or video_id_el.text is None:
                continue

            # Extract media group info
            media_group = entry.find("media:group", ns)
            description = ""
            thumbnail_url = ""
            if media_group is not None:
                desc_el = media_group.find("media:description", ns)
                if desc_el is not None and desc_el.text:
                    description = desc_el.text
                thumb_el = media_group.find("media:thumbnail", ns)
                if thumb_el is not None:
                    thumbnail_url = thumb_el.get("url", "")

            videos.append({
                "video_id": video_id_el.text,
                "title": title_el.text if title_el is not None else "",
                "channel_id": channel_id,
                "channel_title": channel_title,
                "published": published_el.text if published_el is not None else "",
                "thumbnail_url": thumbnail_url,
                "description": description[:2000],
            })

        return videos
