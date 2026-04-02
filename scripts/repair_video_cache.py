#!/usr/bin/env python3
"""Repair unsafe discovery rows and update runtime Piped config."""

from __future__ import annotations

import json
import os
from pathlib import Path
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def load_env() -> dict[str, str]:
    values: dict[str, str] = {}
    for path in (Path("worker/.env"), Path(".env")):
        if not path.exists():
            continue
        for line in path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values.setdefault(key, value.strip())
    values.update(os.environ)
    return values


ENV = load_env()
SUPABASE_BASE = ENV["SUPABASE_URL"].rstrip("/") + "/rest/v1"
SERVICE_KEY = ENV["SUPABASE_SERVICE_ROLE_KEY"]
YOUTUBE_KEY = ENV["YOUTUBE_API_KEY"].split(",")[0]

KIDS_INDICATORS = (
    "kids",
    "children",
    "toddler",
    "preschool",
    "nursery",
    "baby",
    "educational",
    "learning",
    "abc",
    "sesame",
    "cartoon",
    "animation",
    "family friendly",
    "for kids",
    "cocomelon",
    "bluey",
    "peppa",
    "pinkfong",
)
TITLE_BLOCKLIST = (
    "horror",
    "scary",
    "creepy",
    "murder",
    "kill",
    "blood",
    "gore",
    "violence",
    "nsfw",
    "adult",
    "18+",
    "explicit",
    "sex",
    "gun",
    "war",
    "disturbing",
    "suicide",
)


def rest(path: str, method: str = "GET", body: Any | None = None) -> Any:
    headers = {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = Request(
        f"{SUPABASE_BASE}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    with urlopen(request, timeout=30) as response:
        raw = response.read().decode("utf-8")
    return json.loads(raw) if raw else None


def safe_patch(path: str, body: dict[str, Any]) -> None:
    try:
        rest(path, method="PATCH", body=body)
    except Exception:
        fallback = {
            key: value
            for key, value in body.items()
            if key
            not in {
                "is_embeddable",
                "privacy_status",
                "made_for_kids",
                "last_playability_check_at",
            }
        }
        if fallback:
            rest(path, method="PATCH", body=fallback)


def youtube_details(video_ids: list[str]) -> dict[str, dict[str, Any]]:
    if not video_ids:
        return {}
    query = urlencode(
        {
            "part": "snippet,status",
            "id": ",".join(video_ids),
            "key": YOUTUBE_KEY,
        }
    )
    with urlopen(
        f"https://www.googleapis.com/youtube/v3/videos?{query}",
        timeout=30,
    ) as response:
        payload = json.load(response)
    return {item["id"]: item for item in payload.get("items", [])}


def passes_gate(item: dict[str, Any]) -> tuple[bool, str]:
    snippet = item.get("snippet", {})
    status = item.get("status", {})
    title = (snippet.get("title") or "").lower()
    channel = (snippet.get("channelTitle") or "").lower()
    description = (snippet.get("description") or "").lower()
    tags = [str(tag).lower() for tag in snippet.get("tags") or []]
    category_id = int(snippet.get("categoryId") or 0)

    if status.get("madeForKids"):
        return True, "made_for_kids"

    for word in TITLE_BLOCKLIST:
        if word in title or word in description:
            return False, f"blocked term: {word}"

    signals = 0
    for indicator in KIDS_INDICATORS:
        signals += title.count(indicator)
        signals += channel.count(indicator)
        signals += description.count(indicator)
        signals += sum(1 for tag in tags if indicator in tag)

    if signals >= 2:
        return True, "multiple kids signals"
    if category_id in (10, 27) and signals >= 1:
        return True, "kids signal in safer category"
    return False, "insufficient kids signals"


def update_remote_config() -> None:
    safe_patch(
        "/app_config?key=eq.piped_instances",
        body={
            "value": [
                "https://pipedapi.kavin.rocks",
                "https://pipedapi.adminforge.de",
            ]
        },
    )


def repair_trending_rows() -> int:
    rows = rest(
        "/yt_videos?select=video_id,title,analysis_status"
        "&discovery_source=eq.trending"
        "&analysis_status=in.(pending,metadata_approved)"
        "&limit=200"
    )
    details = youtube_details([row["video_id"] for row in rows])
    repaired = 0

    for row in rows:
        video_id = row["video_id"]
        detail = details.get(video_id)
        if detail is None:
            rest(
                f"/yt_videos?video_id=eq.{video_id}",
                method="PATCH",
                body={
                    "analysis_status": "failed",
                    "metadata_gate_passed": False,
                    "metadata_gate_reason": "repair script: video unavailable",
                },
            )
            repaired += 1
            continue

        passed, reason = passes_gate(detail)
        status = detail.get("status", {})
        patch = {
            "metadata_gate_passed": passed,
            "metadata_gate_reason": reason,
            "is_embeddable": status.get("embeddable"),
            "privacy_status": status.get("privacyStatus"),
            "made_for_kids": status.get("madeForKids"),
        }
        if not passed:
            patch["analysis_status"] = "failed"
            safe_patch(
                f"/analysis_queue?video_id=eq.{video_id}&status=in.(queued,processing)",
                body={
                    "status": "failed",
                    "error_message": f"repair script: {reason}",
                },
            )
        safe_patch(f"/yt_videos?video_id=eq.{video_id}", body=patch)
        repaired += 1

    return repaired


def backfill_playability(limit: int = 200) -> int:
    rows = rest(
        "/yt_videos?select=video_id"
        "&is_embeddable=is.null"
        f"&limit={limit}"
    )
    details = youtube_details([row["video_id"] for row in rows])
    updated = 0

    for row in rows:
        video_id = row["video_id"]
        detail = details.get(video_id)
        if detail is None:
            continue
        status = detail.get("status", {})
        safe_patch(
            f"/yt_videos?video_id=eq.{video_id}",
            body={
                "is_embeddable": status.get("embeddable"),
                "privacy_status": status.get("privacyStatus"),
                "made_for_kids": status.get("madeForKids"),
                "last_playability_check_at": datetime.now(timezone.utc).isoformat(),
            },
        )
        updated += 1

    return updated


def main() -> None:
    update_remote_config()
    repaired = repair_trending_rows()
    backfilled = backfill_playability()
    print(
        "Updated app_config.piped_instances, "
        f"repaired {repaired} trending rows, "
        f"and backfilled {backfilled} playability rows."
    )


if __name__ == "__main__":
    main()
