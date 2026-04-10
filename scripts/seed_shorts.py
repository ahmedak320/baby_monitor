#!/usr/bin/env python3
"""Seed the database with curated shorts content.

This script populates yt_videos with short-form content (≤60 seconds)
and sets the is_short flag correctly.

Usage:
    python scripts/seed_shorts.py

Requires:
    pip install httpx supabase python-dotenv
"""

import asyncio
import os
import sys
from pathlib import Path

import httpx
from dotenv import load_dotenv
from supabase import create_client

# Load environment variables
env_path = Path(__file__).parent.parent / ".env"
if env_path.exists():
    load_dotenv(env_path)

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
PIPED_API_URL = os.getenv("PIPED_API_URL", "https://pipedapi.kavin.rocks")
YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY", "")

# Shorts-specific search queries
SHORTS_QUERIES = [
    "kids shorts songs",
    "educational shorts for kids",
    "animal shorts for kids",
    "nursery rhymes shorts",
    "kids learning shorts",
    "fun facts for kids shorts",
    "bedtime stories shorts kids",
    "counting shorts for toddlers",
    "phonics shorts for kids",
    "science shorts for kids",
]

# Known kids channels that post shorts
SHORTS_CHANNELS = [
    "UCbCmjCuTUZos6Inko4u57UQ",  # Cocomelon
    "UCkQO3QsgTpNTsOw6ujimT5Q",  # Pinkfong
    "UClLqfRJVkBGBnMIuR0kWlOg",  # Super Simple Songs
    "UC4NALVCmcmL5ntpV0thoH6w",  # Little Baby Bum
    "UCGwu0nbY2wSkW8N-cghnLpA",  # Blippi
    "UCF3_S8E9PTdYHkhBjRNkyfQ",  # Kids Diana Show
]


def is_short_video(title: str, duration_seconds: int) -> bool:
    """Determine if a video is a short based on duration or title."""
    if 0 < duration_seconds <= 60:
        return True
    if "#shorts" in title.lower():
        return True
    if "short" in title.lower() and duration_seconds <= 90:
        return True
    return False


async def search_piped(client: httpx.AsyncClient, query: str, max_results: int = 20):
    """Search Piped API for videos."""
    try:
        response = await client.get(
            f"{PIPED_API_URL}/search",
            params={"q": query, "filter": "videos"},
            timeout=15.0,
        )
        response.raise_for_status()
        data = response.json()
        items = data.get("items", [])
        return [
            item
            for item in items[:max_results]
            if item.get("type") == "stream"
        ]
    except Exception as e:
        print(f"  Search failed for '{query}': {e}")
        return []


async def get_channel_videos(client: httpx.AsyncClient, channel_id: str):
    """Get recent videos from a channel via Piped."""
    try:
        response = await client.get(
            f"{PIPED_API_URL}/channel/{channel_id}",
            timeout=15.0,
        )
        response.raise_for_status()
        data = response.json()
        return {
            "name": data.get("name", "Unknown"),
            "description": data.get("description", ""),
            "avatar": data.get("avatarUrl", ""),
            "subscribers": data.get("subscriberCount", 0),
            "videos": data.get("relatedStreams", [])[:50],
        }
    except Exception as e:
        print(f"  Channel fetch failed for '{channel_id}': {e}")
        return None


def extract_video_id(url: str) -> str:
    """Extract video ID from /watch?v=XXX URL."""
    if "v=" in url:
        return url.split("v=")[1].split("&")[0]
    return url.split("/")[-1]


def extract_channel_id(url: str) -> str:
    """Extract channel ID from /channel/XXX URL."""
    return url.split("/")[-1]


async def main():
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("Error: Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env")
        sys.exit(1)

    print("Connecting to Supabase...")
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

    videos_to_insert = {}  # video_id -> row data
    channels_to_insert = {}  # channel_id -> row data
    shorts_count = 0

    async with httpx.AsyncClient() as client:
        # Phase 1: Search for shorts-specific content
        print("\n--- Phase 1: Searching for shorts content ---")
        for query in SHORTS_QUERIES:
            print(f"  Searching: {query}")
            items = await search_piped(client, query, max_results=15)
            for item in items:
                vid_url = item.get("url", "")
                video_id = extract_video_id(vid_url)
                if not video_id or video_id in videos_to_insert:
                    continue

                duration = item.get("duration", 0)
                title = item.get("title", "")

                # Only include shorts (≤60s or has #shorts in title)
                if not is_short_video(title, duration):
                    continue

                channel_url = item.get("uploaderUrl", "")
                channel_id = extract_channel_id(channel_url) if channel_url else ""

                if channel_id and channel_id not in channels_to_insert:
                    channels_to_insert[channel_id] = {
                        "channel_id": channel_id,
                        "title": item.get("uploaderName", "Unknown"),
                    }

                videos_to_insert[video_id] = {
                    "video_id": video_id,
                    "channel_id": channel_id or None,
                    "title": title,
                    "description": item.get("shortDescription", ""),
                    "thumbnail_url": item.get("thumbnail", ""),
                    "duration_seconds": duration,
                    "view_count": item.get("views", 0),
                    "is_short": True,
                    "analysis_status": "pending",
                    "discovery_source": "shorts_seed",
                }
                shorts_count += 1
            print(f"  Found {len(items)} videos, {shorts_count} shorts so far")
            await asyncio.sleep(0.5)

        # Phase 2: Check known channels for shorts
        print("\n--- Phase 2: Checking known channels for shorts ---")
        for channel_id in SHORTS_CHANNELS:
            print(f"  Fetching channel: {channel_id}")
            channel_data = await get_channel_videos(client, channel_id)
            if channel_data is None:
                continue

            channels_to_insert[channel_id] = {
                "channel_id": channel_id,
                "title": channel_data["name"],
                "description": channel_data["description"][:500] if channel_data["description"] else "",
                "thumbnail_url": channel_data["avatar"],
                "subscriber_count": channel_data["subscribers"],
                "is_kids_channel": True,
            }

            channel_shorts = 0
            for item in channel_data["videos"]:
                vid_url = item.get("url", "")
                video_id = extract_video_id(vid_url)
                if not video_id or video_id in videos_to_insert:
                    continue

                duration = item.get("duration", 0)
                title = item.get("title", "")

                # Only include shorts
                if not is_short_video(title, duration):
                    continue

                videos_to_insert[video_id] = {
                    "video_id": video_id,
                    "channel_id": channel_id,
                    "title": title,
                    "thumbnail_url": item.get("thumbnail", ""),
                    "duration_seconds": duration,
                    "view_count": item.get("views", 0),
                    "is_short": True,
                    "analysis_status": "pending",
                    "discovery_source": "shorts_seed",
                }
                shorts_count += 1
                channel_shorts += 1
            print(f"  Added {channel_shorts} shorts from {channel_data['name']}")
            await asyncio.sleep(0.5)

    # Phase 3: Insert into Supabase
    print(f"\n--- Phase 3: Inserting into Supabase ---")
    print(f"  Channels: {len(channels_to_insert)}")
    print(f"  Shorts videos: {len(videos_to_insert)}")

    # Insert channels in batches
    channel_rows = list(channels_to_insert.values())
    batch_size = 50
    for i in range(0, len(channel_rows), batch_size):
        batch = channel_rows[i : i + batch_size]
        try:
            supabase.table("yt_channels").upsert(batch, on_conflict="channel_id").execute()
            print(f"  Inserted channels batch {i // batch_size + 1}")
        except Exception as e:
            print(f"  Channel batch error: {e}")

    # Insert videos in batches
    video_rows = list(videos_to_insert.values())
    for i in range(0, len(video_rows), batch_size):
        batch = video_rows[i : i + batch_size]
        try:
            supabase.table("yt_videos").upsert(batch, on_conflict="video_id").execute()
            print(f"  Inserted videos batch {i // batch_size + 1}")
        except Exception as e:
            print(f"  Video batch error: {e}")

    # Phase 4: Queue for analysis
    print(f"\n--- Phase 4: Queueing for analysis ---")
    queued = 0
    for video_id in videos_to_insert.keys():
        try:
            # Check if already queued
            existing = (
                supabase.table("analysis_queue")
                .select("id")
                .eq("video_id", video_id)
                .in_("status", ["queued", "processing", "completed"])
                .execute()
            )
            if not existing.data:
                supabase.table("analysis_queue").insert({
                    "video_id": video_id,
                    "priority": 8,
                    "source": "shorts_seed",
                }).execute()
                queued += 1
        except Exception as e:
            print(f"  Queue error for {video_id}: {e}")

    print(f"\nDone! Seeded {len(channels_to_insert)} channels and {len(videos_to_insert)} shorts.")
    print(f"Queued {queued} videos for analysis.")
    print("\nNext steps:")
    print("1. Run the worker to analyze the seeded shorts:")
    print("   cd worker && python main.py")
    print("2. The shorts should appear in the app after analysis completes")


if __name__ == "__main__":
    asyncio.run(main())
