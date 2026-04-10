#!/usr/bin/env python3
"""Seed the database with curated shorts content using YouTube API.

This script uses the YouTube Data API v3 to find actual shorts.

Usage:
    python scripts/seed_shorts_youtube.py

Requires:
    pip install google-api-python-client supabase python-dotenv
"""

import os
import sys
from pathlib import Path
from datetime import datetime

from dotenv import load_dotenv
from supabase import create_client

# Try to import google api client
try:
    from googleapiclient.discovery import build
except ImportError:
    print("Error: google-api-python-client not installed")
    print("Run: pip install google-api-python-client")
    sys.exit(1)

# Load environment variables
env_path = Path(__file__).parent.parent / ".env"
if env_path.exists():
    load_dotenv(env_path)

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
YOUTUBE_API_KEYS = os.getenv("YOUTUBE_API_KEYS", os.getenv("YOUTUBE_API_KEY", ""))

# YouTube Shorts-specific search queries
SHORTS_SEARCH_QUERIES = [
    "#shorts kids educational",
    "#shorts nursery rhymes",
    "#shorts kids songs",
    "#shorts baby shark",
    "#shorts cocomelon",
    "#shorts kids learning",
    "#shorts animals for kids",
    "#shorts counting for kids",
    "#shorts phonics for kids",
    "#shorts colors for toddlers",
]

# Known YouTube Shorts video IDs (actual shorts under 60 seconds)
# These are popular kids shorts content
CURATED_SHORTS_IDS = [
    # Add known short video IDs here - these are placeholder examples
    # Format: video ID that is confirmed to be a short (under 60s)
]


def get_youtube_client():
    """Create YouTube API client with key rotation."""
    if not YOUTUBE_API_KEYS:
        print("Error: No YouTube API keys found. Set YOUTUBE_API_KEYS or YOUTUBE_API_KEY")
        return None
    
    keys = [k.strip() for k in YOUTUBE_API_KEYS.split(",") if k.strip()]
    for key in keys:
        try:
            youtube = build("youtube", "v3", developerKey=key, cache_discovery=False)
            # Test the key
            youtube.videos().list(part="snippet", id="dQw4w9WgXcQ").execute()
            print(f"Using YouTube API key: {key[:10]}...")
            return youtube
        except Exception as e:
            print(f"Key {key[:10]}... failed: {e}")
            continue
    
    print("Error: All YouTube API keys failed")
    return None


def search_shorts(youtube, query, max_results=10):
    """Search for shorts using YouTube API."""
    try:
        # Search for videos
        search_response = youtube.search().list(
            q=query,
            type="video",
            videoDuration="short",  # This filters for videos under 4 minutes
            part="id,snippet",
            maxResults=max_results,
            safeSearch="strict",
        ).execute()
        
        items = search_response.get("items", [])
        video_ids = [item["id"]["videoId"] for item in items if "videoId" in item.get("id", {})]
        
        if not video_ids:
            return []
        
        # Get detailed info including duration
        videos_response = youtube.videos().list(
            id=",".join(video_ids),
            part="snippet,contentDetails,statistics",
        ).execute()
        
        shorts = []
        for item in videos_response.get("items", []):
            duration_str = item.get("contentDetails", {}).get("duration", "PT0S")
            duration = parse_duration(duration_str)
            
            # Only include actual shorts (<=60 seconds)
            if duration <= 60 and duration > 0:
                shorts.append(item)
        
        return shorts
        
    except Exception as e:
        print(f"  Search failed: {e}")
        return []


def parse_duration(duration_str):
    """Parse ISO 8601 duration to seconds."""
    import re
    match = re.match(r"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?", duration_str)
    if not match:
        return 0
    hours = int(match.group(1) or 0)
    minutes = int(match.group(2) or 0)
    seconds = int(match.group(3) or 0)
    return hours * 3600 + minutes * 60 + seconds


def main():
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("Error: Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env")
        sys.exit(1)

    print("Connecting to Supabase...")
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

    print("Connecting to YouTube API...")
    youtube = get_youtube_client()
    if not youtube:
        sys.exit(1)

    videos_to_insert = {}
    channels_to_insert = {}

    # Search for shorts
    print("\n--- Searching for shorts on YouTube ---")
    for query in SHORTS_SEARCH_QUERIES:
        print(f"  Searching: {query}")
        shorts = search_shorts(youtube, query, max_results=5)
        
        for item in shorts:
            video_id = item["id"]
            if video_id in videos_to_insert:
                continue
            
            snippet = item.get("snippet", {})
            content_details = item.get("contentDetails", {})
            statistics = item.get("statistics", {})
            
            title = snippet.get("title", "")
            duration_str = content_details.get("duration", "PT0S")
            duration = parse_duration(duration_str)
            channel_id = snippet.get("channelId", "")
            channel_title = snippet.get("channelTitle", "")
            
            # Add channel
            if channel_id and channel_id not in channels_to_insert:
                channels_to_insert[channel_id] = {
                    "channel_id": channel_id,
                    "title": channel_title,
                }
            
            videos_to_insert[video_id] = {
                "video_id": video_id,
                "channel_id": channel_id or None,
                "title": title,
                "description": snippet.get("description", "")[:500],
                "thumbnail_url": snippet.get("thumbnails", {}).get("high", {}).get("url", "")
                or snippet.get("thumbnails", {}).get("default", {}).get("url", ""),
                "duration_seconds": duration,
                "view_count": int(statistics.get("viewCount", 0)),
                "like_count": int(statistics.get("likeCount", 0)) if "likeCount" in statistics else 0,
                "is_short": True,
                "analysis_status": "pending",
                "discovery_source": "shorts_youtube_search",
                "published_at": snippet.get("publishedAt"),
            }
            print(f"    Found short: {title[:50]} ({duration}s)")
        
        print(f"    Found {len(shorts)} shorts this query")

    print(f"\n--- Inserting into Supabase ---")
    print(f"  Channels: {len(channels_to_insert)}")
    print(f"  Shorts: {len(videos_to_insert)}")

    # Insert channels
    if channels_to_insert:
        channel_rows = list(channels_to_insert.values())
        try:
            supabase.table("yt_channels").upsert(channel_rows, on_conflict="channel_id").execute()
            print(f"  Inserted {len(channel_rows)} channels")
        except Exception as e:
            print(f"  Channel insert error: {e}")

    # Insert videos
    if videos_to_insert:
        video_rows = list(videos_to_insert.values())
        try:
            supabase.table("yt_videos").upsert(video_rows, on_conflict="video_id").execute()
            print(f"  Inserted {len(video_rows)} videos")
        except Exception as e:
            print(f"  Video insert error: {e}")

    # Queue for analysis
    print(f"\n--- Queueing for analysis ---")
    queued = 0
    for video_id in videos_to_insert.keys():
        try:
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
                    "priority": 5,
                    "source": "shorts_youtube_search",
                }).execute()
                queued += 1
        except Exception as e:
            print(f"  Queue error for {video_id}: {e}")

    print(f"\nDone! Seeded {len(channels_to_insert)} channels and {len(videos_to_insert)} shorts.")
    print(f"Queued {queued} videos for analysis.")
    print("\nNext steps:")
    print("1. Run the worker to analyze the shorts:")
    print("   cd worker && python main.py")
    print("2. The shorts will appear in the app once analysis completes")


if __name__ == "__main__":
    main()
