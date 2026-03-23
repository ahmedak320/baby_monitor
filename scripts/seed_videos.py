#!/usr/bin/env python3
"""Seed the database with curated kids' YouTube video IDs.

This script populates the yt_channels and yt_videos tables with
pre-selected content across all age groups and categories.
It uses the Piped API to avoid YouTube API quota during seeding.

Usage:
    python scripts/seed_videos.py

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

# Curated search queries by age group and category
SEED_QUERIES = {
    # Toddlers (1-3)
    "toddler_music": [
        "nursery rhymes for babies",
        "baby songs cocomelon",
        "lullabies for babies",
        "abc songs for toddlers",
    ],
    "toddler_sensory": [
        "baby sensory videos",
        "hey bear sensory",
        "calming videos for babies",
        "colorful shapes for babies",
    ],
    # Preschool (3-6)
    "preschool_educational": [
        "numberblocks full episodes",
        "sesame street learning",
        "peppa pig episodes",
        "bluey full episodes",
    ],
    "preschool_nature": [
        "animals for kids preschool",
        "baby animals documentary",
        "ocean animals for kids",
    ],
    # Early School (5-8)
    "school_science": [
        "science experiments for kids",
        "scishow kids",
        "national geographic kids",
        "how things work for kids",
    ],
    "school_creative": [
        "art for kids hub",
        "easy drawing for kids",
        "craft ideas for children",
    ],
    "school_cartoons": [
        "pbs kids full episodes",
        "wild kratts full episodes",
        "magic school bus",
    ],
    # Older Kids (8-12)
    "older_science": [
        "mark rober science",
        "cool science experiments",
        "space documentaries for kids",
    ],
    "older_educational": [
        "history for kids",
        "geography for kids",
        "ted ed animation",
    ],
    "older_nature": [
        "wildlife documentary HD",
        "planet earth clips",
        "ocean documentary for kids",
    ],
}

# Known safe channels to seed directly
SEED_CHANNELS = [
    "UCbCmjCuTUZos6Inko4u57UQ",  # Cocomelon
    "UCWI-ohtRu8eoyisLmPsTCrQ",  # Sesame Street
    "UCLsooMJoIpl_7ux2jvdPB-Q",  # Peppa Pig Official
    "UC4KObfhPm_HMGP2WFHF6HmQ",  # Numberblocks
    "UC0v-tlzsn0QZwJnkiaUSJCKg",  # Nat Geo Kids
    "UCvO6uJUVJQ6SrATfsufsprA",  # SciShow Kids
    "UCVcQH8A634mauPrGbWs7jlg",  # Art for Kids Hub
    "UC-Gkp36O-TIBdQRPgDzNYkQ",  # Hey Bear Sensory
]


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
            "videos": data.get("relatedStreams", [])[:30],
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

    async with httpx.AsyncClient() as client:
        # Phase 1: Search queries
        print("\n--- Phase 1: Searching for kids content ---")
        for category, queries in SEED_QUERIES.items():
            print(f"\nCategory: {category}")
            for query in queries:
                print(f"  Searching: {query}")
                items = await search_piped(client, query)
                for item in items:
                    vid_url = item.get("url", "")
                    video_id = extract_video_id(vid_url)
                    if not video_id or video_id in videos_to_insert:
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
                        "title": item.get("title", ""),
                        "description": item.get("shortDescription", ""),
                        "thumbnail_url": item.get("thumbnail", ""),
                        "duration_seconds": item.get("duration", 0),
                        "view_count": item.get("views", 0),
                        "analysis_status": "pending",
                    }
                print(f"  Found {len(items)} videos. Total unique: {len(videos_to_insert)}")
                await asyncio.sleep(0.5)  # Rate limiting

        # Phase 2: Channel uploads
        print("\n--- Phase 2: Fetching channel uploads ---")
        for channel_id in SEED_CHANNELS:
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

            for item in channel_data["videos"]:
                vid_url = item.get("url", "")
                video_id = extract_video_id(vid_url)
                if not video_id or video_id in videos_to_insert:
                    continue

                videos_to_insert[video_id] = {
                    "video_id": video_id,
                    "channel_id": channel_id,
                    "title": item.get("title", ""),
                    "thumbnail_url": item.get("thumbnail", ""),
                    "duration_seconds": item.get("duration", 0),
                    "view_count": item.get("views", 0),
                    "analysis_status": "pending",
                }
            print(f"  Added {len(channel_data['videos'])} videos from {channel_data['name']}")
            await asyncio.sleep(0.5)

    # Phase 3: Insert into Supabase
    print(f"\n--- Phase 3: Inserting into Supabase ---")
    print(f"  Channels: {len(channels_to_insert)}")
    print(f"  Videos: {len(videos_to_insert)}")

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

    print(f"\nDone! Seeded {len(channels_to_insert)} channels and {len(videos_to_insert)} videos.")


if __name__ == "__main__":
    asyncio.run(main())
