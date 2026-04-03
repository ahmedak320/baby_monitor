"""Write analysis results to Supabase."""

import logging

from models.analysis_result import AnalysisResult
from utils.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)


class ResultWriter:
    """Write analysis results to the video_analyses table."""

    def __init__(self):
        self._client = get_supabase_client()

    def write(self, result: AnalysisResult, model_version: str = "v1") -> bool:
        """Write or update an analysis result.

        Returns True if successful.
        """
        try:
            row = {
                "video_id": result.video_id,
                "tiers_completed": result.tiers_completed,
                "age_min_appropriate": result.scores.age_min_appropriate,
                "age_max_appropriate": result.scores.age_max_appropriate,
                "overstimulation_score": result.scores.overstimulation_score,
                "educational_score": result.scores.educational_score,
                "scariness_score": result.scores.scariness_score,
                "brainrot_score": result.scores.brainrot_score,
                "language_safety_score": result.scores.language_safety_score,
                "violence_score": result.scores.violence_score,
                "ad_commercial_score": result.scores.ad_commercial_score,
                "audio_safety_score": result.scores.audio_safety_score,
                "content_labels": result.content_labels,
                "detected_issues": result.detected_issues,
                "analysis_reasoning": result.analysis_reasoning[:5000],
                "confidence": result.confidence,
                "verdict": result.verdict.value,
                "model_version": model_version,
            }

            self._client.table("video_analyses").upsert(
                row, on_conflict="video_id"
            ).execute()

            # Update video analysis_status
            status = "completed" if result.confidence > 0.5 else "pending"
            self._client.table("yt_videos").update(
                {"analysis_status": status}
            ).eq("video_id", result.video_id).execute()

            logger.info(
                "Wrote analysis for %s: verdict=%s, confidence=%.2f",
                result.video_id,
                result.verdict.value,
                result.confidence,
            )
            return True

        except Exception as e:
            logger.error("Failed to write result for %s: %s", result.video_id, e)
            return False

    def mark_failed(self, video_id: str, error: str) -> None:
        """Mark a video analysis as failed."""
        try:
            self._client.table("yt_videos").update(
                {"analysis_status": "failed"}
            ).eq("video_id", video_id).execute()

            logger.info("Marked %s as failed: %s", video_id, error[:200])
        except Exception as e:
            logger.error("Failed to mark %s as failed: %s", video_id, e)
