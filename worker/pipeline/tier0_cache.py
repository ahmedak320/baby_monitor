"""Tier 0: Community cache lookup.

Cost: $0
Resolves: 60-80% of popular kids content (already analyzed by another user)
"""

import logging

from models.analysis_result import AnalysisResult, AnalysisScores, Verdict
from utils.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)


class Tier0Cache:
    """Check community cache for existing analysis."""

    def __init__(self):
        self._client = get_supabase_client()

    def lookup(self, video_id: str) -> AnalysisResult | None:
        """Check if this video has already been analyzed.

        Returns cached AnalysisResult if found with sufficient confidence,
        otherwise None.
        """
        try:
            result = (
                self._client.table("video_analyses")
                .select("*")
                .eq("video_id", video_id)
                .gte("confidence", 0.7)
                .limit(1)
                .execute()
            )

            if not result.data:
                logger.info("Cache miss for %s", video_id)
                return None

            data = result.data[0]
            logger.info(
                "Cache hit for %s: confidence=%.2f",
                video_id,
                data.get("confidence", 0),
            )

            tiers = data.get("tiers_completed", [])
            confidence = data.get("confidence", 0)

            # Determine verdict from stored analysis
            is_blacklisted = data.get("is_globally_blacklisted", False)
            stored_verdict = data.get("verdict", "").upper()

            if is_blacklisted or stored_verdict == "REJECT":
                verdict = Verdict.REJECT
            elif stored_verdict == "APPROVE":
                verdict = Verdict.APPROVE
            else:
                return None  # Inconclusive cached result

            return AnalysisResult(
                video_id=video_id,
                verdict=verdict,
                scores=AnalysisScores(
                    age_min_appropriate=data.get("age_min_appropriate", 0),
                    age_max_appropriate=data.get("age_max_appropriate", 18),
                    overstimulation_score=data.get("overstimulation_score") or 0,
                    educational_score=data.get("educational_score") or 0,
                    scariness_score=data.get("scariness_score") or 0,
                    brainrot_score=data.get("brainrot_score") or 0,
                    language_safety_score=data.get("language_safety_score") or 10,
                    violence_score=data.get("violence_score") or 0,
                    ad_commercial_score=data.get("ad_commercial_score") or 0,
                    audio_safety_score=data.get("audio_safety_score") or 10,
                ),
                tiers_completed=tiers,
                content_labels=data.get("content_labels") or [],
                detected_issues=data.get("detected_issues") or [],
                analysis_reasoning=data.get("analysis_reasoning") or "",
                confidence=confidence,
            )

        except Exception as e:
            logger.error("Cache lookup failed for %s: %s", video_id, e)
            return None
