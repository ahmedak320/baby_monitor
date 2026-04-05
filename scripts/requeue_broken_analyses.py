"""Re-queue broken analyses that failed due to Gemini errors or frame extraction failures.

Run once after fixing the worker pipeline:
    cd scripts && python requeue_broken_analyses.py
"""

import os
import sys
import uuid
from datetime import datetime, timezone

worker_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "worker")
sys.path.insert(0, worker_dir)

from dotenv import load_dotenv

# Load .env from worker directory
load_dotenv(os.path.join(worker_dir, ".env"))

from supabase import create_client

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
client = create_client(url, key)


def find_broken_analyses():
    """Find analyses that are degraded and need re-processing."""
    # 1. Frame extraction failures with low confidence
    frame_fail = (
        client.table("video_analyses")
        .select("video_id, confidence, verdict, detected_issues")
        .contains("detected_issues", ["frame_extraction_failed"])
        .lt("confidence", 0.5)
        .execute()
    )

    # 2. Gemini error analyses with low confidence
    gemini_err = (
        client.table("video_analyses")
        .select("video_id, confidence, verdict, analysis_reasoning")
        .like("analysis_reasoning", "%encountered an error%")
        .lt("confidence", 0.6)
        .execute()
    )

    # Deduplicate
    broken_ids = set()
    for row in frame_fail.data:
        broken_ids.add(row["video_id"])
    for row in gemini_err.data:
        broken_ids.add(row["video_id"])

    return broken_ids


def requeue_videos(video_ids: set[str]):
    """Delete broken analyses, reset video status, and re-queue."""
    if not video_ids:
        print("No broken analyses found.")
        return

    print(f"Found {len(video_ids)} broken analyses to re-queue.")

    for vid in video_ids:
        try:
            # Delete the broken analysis
            client.table("video_analyses").delete().eq("video_id", vid).execute()

            # Reset video status to pending
            client.table("yt_videos").update(
                {"analysis_status": "pending"}
            ).eq("video_id", vid).execute()

            # Check if already queued
            existing = (
                client.table("analysis_queue")
                .select("id")
                .eq("video_id", vid)
                .in_("status", ["queued", "processing"])
                .execute()
            )
            if existing.data:
                print(f"  {vid}: already queued, skipping queue insert")
                continue

            # Insert new queue entry
            client.table("analysis_queue").insert({
                "id": str(uuid.uuid4()),
                "video_id": vid,
                "priority": 8,
                "status": "queued",
                "attempts": 0,
                "max_attempts": 3,
                "source": "requeue_broken",
                "created_at": datetime.now(timezone.utc).isoformat(),
            }).execute()

            print(f"  {vid}: re-queued")

        except Exception as e:
            print(f"  {vid}: ERROR — {e}")

    print(f"\nDone. {len(video_ids)} videos re-queued for analysis.")


if __name__ == "__main__":
    broken = find_broken_analyses()
    requeue_videos(broken)
