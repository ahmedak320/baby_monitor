"""Pipeline orchestrator — chains analysis tiers and decides when to stop."""

import logging

from config import settings
from models.analysis_result import AnalysisResult, Verdict
from models.video_metadata import VideoMetadata
from pipeline.result_writer import ResultWriter
from pipeline.tier0_cache import Tier0Cache
from pipeline.tier05_embedding import Tier05Embedding
from pipeline.tier1_text import Tier1TextPipeline
from pipeline.tier2_visual import Tier2VisualPipeline
from pipeline.tier3_audio import Tier3AudioPipeline
from providers.provider_factory import get_provider
from utils.cost_tracker import AnalysisCost
from utils.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)


class PipelineOrchestrator:
    """Run videos through the tiered analysis funnel.

    Tier execution order:
    0.  Community cache lookup ($0) — skip if already analyzed
    0.5 Embedding similarity pre-filter (~$0.0001) — fast-track similar videos
    1.  Metadata + transcript text analysis (~$0.001-0.003)
    2.  Visual frame analysis (~$0.005-0.015) — only if Tier 1 can't decide
    3.  Audio analysis (~$0.005) — only if flagged for audio review

    Stops early when confidence is high enough.
    AI provider is configurable via AI_PROVIDER env var.
    """

    def __init__(self, provider_name: str | None = None):
        self._tier0 = Tier0Cache()
        self._tier05 = Tier05Embedding()
        self._tier1 = Tier1TextPipeline()
        self._tier2 = Tier2VisualPipeline()
        self._tier3 = Tier3AudioPipeline()
        self._writer = ResultWriter()
        self._provider = get_provider(provider_name or settings.ai_provider)
        logger.info("Pipeline using AI provider: %s", self._provider.get_provider_name())

    def analyze(self, video_id: str) -> AnalysisResult:
        """Run full analysis pipeline on a video."""
        cost = AnalysisCost(video_id=video_id)
        logger.info("=== Pipeline starting for: %s ===", video_id)

        # Tier 0: Community cache
        cached = self._tier0.lookup(video_id)
        if cached is not None:
            logger.info("Tier 0 cache hit — returning cached result")
            return cached

        # Fetch video metadata from Supabase
        metadata = self._fetch_metadata(video_id)
        if metadata is None:
            logger.error("No metadata found for %s", video_id)
            return AnalysisResult(
                video_id=video_id,
                verdict=Verdict.PENDING,
                analysis_reasoning="Metadata not found",
            )

        # Tier 0.5: Embedding pre-filter
        if self._tier05.is_available:
            fast_track = self._tier05.fast_track(metadata)
            if fast_track is not None:
                logger.info(
                    "Tier 0.5 fast-track: verdict=%s, confidence=%.2f",
                    fast_track["verdict"],
                    fast_track["confidence"],
                )
                verdict = (
                    Verdict.APPROVE
                    if fast_track["verdict"] == "approve"
                    else Verdict.REJECT
                )
                result = AnalysisResult(
                    video_id=video_id,
                    verdict=verdict,
                    confidence=fast_track["confidence"],
                    analysis_reasoning="Fast-tracked via embedding similarity",
                    tiers_completed=["0.5"],
                )
                self._writer.write(result)
                return result

        # Tier 1: Text analysis
        result = self._tier1.analyze(metadata)
        logger.info(
            "Tier 1 result: verdict=%s, confidence=%.2f",
            result.verdict.value,
            result.confidence,
        )

        # Early stop: Tier 1 is confident enough
        if result.confidence >= settings.tier1_confidence_threshold:
            if result.verdict in (Verdict.APPROVE, Verdict.REJECT):
                logger.info("Tier 1 confident — stopping early")
                self._writer.write(result)
                return result

        # Tier 2: Visual analysis (if needed)
        if result.verdict in (Verdict.NEEDS_VISUAL_REVIEW, Verdict.PENDING) or \
           result.confidence < settings.tier1_confidence_threshold:
            result = self._tier2.analyze(metadata, result)
            logger.info(
                "Tier 2 result: verdict=%s, confidence=%.2f",
                result.verdict.value,
                result.confidence,
            )

            # Early stop: Tier 2 resolved it
            if result.confidence >= settings.tier2_confidence_threshold:
                if result.verdict in (Verdict.APPROVE, Verdict.REJECT):
                    logger.info("Tier 2 confident — stopping early")
                    self._writer.write(result)
                    return result

        # Tier 3: Audio analysis (if flagged)
        if result.verdict == Verdict.NEEDS_AUDIO_REVIEW or \
           result.scores.audio_safety_score < 7:
            result = self._tier3.analyze(metadata, result)
            logger.info(
                "Tier 3 result: verdict=%s, confidence=%.2f",
                result.verdict.value,
                result.confidence,
            )

        # Write final result
        self._writer.write(result)
        cost.log_summary()

        logger.info(
            "=== Pipeline complete for %s: verdict=%s, provider=%s, tiers=%s ===",
            video_id,
            result.verdict.value,
            self._provider.get_provider_name(),
            result.tiers_completed,
        )

        return result

    def _fetch_metadata(self, video_id: str) -> VideoMetadata | None:
        """Fetch video metadata from Supabase."""
        try:
            client = get_supabase_client()
            row = (
                client.table("yt_videos")
                .select("*, yt_channels(title)")
                .eq("video_id", video_id)
                .maybe_single()
                .execute()
            )

            if row.data is None:
                return None

            data = row.data
            channel_title = ""
            if data.get("yt_channels") and isinstance(data["yt_channels"], dict):
                channel_title = data["yt_channels"].get("title", "")

            return VideoMetadata(
                video_id=data["video_id"],
                title=data.get("title", ""),
                description=data.get("description", ""),
                channel_id=data.get("channel_id", ""),
                channel_title=channel_title,
                thumbnail_url=data.get("thumbnail_url", ""),
                duration_seconds=data.get("duration_seconds", 0),
                tags=data.get("tags") or [],
                category_id=data.get("category_id", 0),
                has_captions=data.get("has_captions", False),
                view_count=data.get("view_count", 0),
                like_count=data.get("like_count", 0),
            )

        except Exception as e:
            logger.error("Failed to fetch metadata for %s: %s", video_id, e)
            return None
