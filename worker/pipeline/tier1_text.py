"""Tier 1: Metadata + transcript text analysis.

Cost: ~$0.003/video
Resolves: ~40% of videos (clear approve/reject from text alone)
"""

import logging

from analyzers.haiku_text_analyzer import HaikuTextAnalyzer, HaikuTextResult
from analyzers.toxicity_analyzer import ToxicityAnalyzer, ToxicityResult
from extractors.caption_extractor import CaptionExtractor
from models.analysis_result import AnalysisResult, AnalysisScores, Verdict
from models.video_metadata import VideoMetadata

logger = logging.getLogger(__name__)


class Tier1TextPipeline:
    """Tier 1: Analyze video using metadata and transcript text only.

    Pipeline:
    1. Extract transcript via youtube-transcript-api
    2. Run transcript through Detoxify + HateSonar
    3. Send metadata + toxicity scores + transcript to Claude Haiku
    4. Return structured result with verdict
    """

    def __init__(self):
        self._caption_extractor = CaptionExtractor()
        self._toxicity_analyzer = ToxicityAnalyzer()
        self._haiku_analyzer = HaikuTextAnalyzer()

    def analyze(self, metadata: VideoMetadata) -> AnalysisResult:
        """Run Tier 1 analysis on a video."""
        logger.info("Tier 1 starting for: %s (%s)", metadata.video_id, metadata.title)

        # Step 1: Extract transcript
        transcript_text = ""
        transcript = self._caption_extractor.extract(metadata.video_id)
        if transcript:
            transcript_text = transcript.full_text
            logger.info("Transcript: %d chars", len(transcript_text))
        else:
            logger.info("No transcript available for %s", metadata.video_id)

        # Step 2: Run toxicity analysis on transcript + title + description
        combined_text = f"{metadata.title} {metadata.description} {transcript_text}"
        toxicity: ToxicityResult = self._toxicity_analyzer.analyze_chunks(combined_text)

        toxicity_summary = (
            f"toxicity={toxicity.toxicity:.2f}, "
            f"severe={toxicity.severe_toxicity:.2f}, "
            f"obscene={toxicity.obscene:.2f}, "
            f"threat={toxicity.threat:.2f}, "
            f"hate_speech={toxicity.hate_speech_score:.2f}"
        )

        # Quick reject: if toxicity is extremely high, skip Haiku
        if toxicity.severe_toxicity > 0.8 or toxicity.hate_speech_score > 0.8:
            logger.info("Quick reject: extreme toxicity for %s", metadata.video_id)
            return AnalysisResult(
                video_id=metadata.video_id,
                verdict=Verdict.REJECT,
                scores=AnalysisScores(
                    language_safety_score=toxicity.safety_score_1_10,
                ),
                tiers_completed=[1],
                detected_issues=toxicity.concerns,
                analysis_reasoning="Rejected by toxicity pre-filter",
                confidence=0.95,
            )

        # Step 3: Claude Haiku text analysis
        haiku_result: HaikuTextResult = self._haiku_analyzer.analyze(
            title=metadata.title,
            channel=metadata.channel_title or metadata.channel_id,
            description=metadata.description,
            tags=metadata.tags,
            duration_seconds=metadata.duration_seconds,
            transcript=transcript_text,
            toxicity_summary=toxicity_summary,
        )

        # Build result
        verdict = self._map_verdict(haiku_result.overall_verdict)
        confidence = self._calculate_confidence(haiku_result, toxicity, transcript_text)

        scores = AnalysisScores(
            age_min_appropriate=haiku_result.age_min_appropriate,
            age_max_appropriate=haiku_result.age_max_appropriate,
            overstimulation_score=haiku_result.overstimulation_score,
            educational_score=haiku_result.educational_score,
            scariness_score=haiku_result.scariness_score,
            brainrot_score=haiku_result.brainrot_score,
            language_safety_score=min(
                haiku_result.language_safety_score,
                toxicity.safety_score_1_10,
            ),
            ad_commercial_score=haiku_result.ad_commercial_score,
        )

        result = AnalysisResult(
            video_id=metadata.video_id,
            verdict=verdict,
            scores=scores,
            tiers_completed=[1],
            content_labels=haiku_result.content_labels,
            detected_issues=haiku_result.detected_issues + toxicity.concerns,
            analysis_reasoning=haiku_result.reasoning,
            confidence=confidence,
        )

        logger.info(
            "Tier 1 complete for %s: verdict=%s, confidence=%.2f",
            metadata.video_id,
            verdict.value,
            confidence,
        )

        return result

    def _map_verdict(self, haiku_verdict: str) -> Verdict:
        v = haiku_verdict.upper()
        if v == "APPROVE":
            return Verdict.APPROVE
        if v == "REJECT":
            return Verdict.REJECT
        if v == "NEEDS_AUDIO_REVIEW":
            return Verdict.NEEDS_AUDIO_REVIEW
        return Verdict.NEEDS_VISUAL_REVIEW

    def _calculate_confidence(
        self,
        haiku: HaikuTextResult,
        toxicity: ToxicityResult,
        transcript: str,
    ) -> float:
        """Estimate confidence in the Tier 1 result."""
        confidence = 0.6  # base

        # Boost if transcript was available (much more data)
        if len(transcript) > 500:
            confidence += 0.15
        elif len(transcript) > 100:
            confidence += 0.08

        # Boost if toxicity and Haiku agree
        both_safe = toxicity.is_safe and haiku.overall_verdict == "APPROVE"
        both_unsafe = not toxicity.is_safe and haiku.overall_verdict == "REJECT"
        if both_safe or both_unsafe:
            confidence += 0.10

        # Reduce if Haiku says needs review
        if haiku.overall_verdict == "NEEDS_VISUAL_REVIEW":
            confidence -= 0.20

        return max(0.1, min(0.95, confidence))
