"""Tier 2: Visual frame analysis.

Cost: ~$0.015/video
Resolves: videos that Tier 1 couldn't confidently classify
"""

import logging
from dataclasses import dataclass, field

from analyzers.nsfw_classifier import NSFWClassifier
from analyzers.violence_classifier import ViolenceClassifier
from extractors.frame_extractor import FrameExtractor
from models.analysis_result import AnalysisResult, AnalysisScores, Verdict
from models.video_metadata import VideoMetadata
from providers.base_provider import AnalysisProvider, ImageAnalysisResult

logger = logging.getLogger(__name__)


@dataclass
class VisionResult:
    """Adapter mapping ImageAnalysisResult to the fields _merge_results expects."""

    visual_overstimulation: float = 5.0
    visual_scariness: float = 5.0
    visual_violence: float = 1.0
    visual_quality: float = 5.0
    visual_concerns: list[str] = field(default_factory=list)
    visual_verdict: str = "APPROVE"
    reasoning: str = ""


def _adapt_image_result(result: ImageAnalysisResult) -> VisionResult:
    """Convert a provider's ImageAnalysisResult to the format Tier 2 merger expects."""
    return VisionResult(
        visual_overstimulation=result.overstimulation_score,
        visual_scariness=result.scariness_score,
        visual_violence=result.violence_score,
        visual_verdict=result.overall_verdict,
        reasoning=result.reasoning,
    )


class Tier2VisualPipeline:
    """Tier 2: Analyze video using sampled frames.

    Pipeline:
    1. Download video and extract frames (yt-dlp + OpenCV)
    2. Run NSFW classifier on all frames
    3. Run violence/overstimulation detector
    4. If concerns or borderline: send frames to AI provider vision
    5. Merge visual scores with Tier 1 scores
    """

    def __init__(self, provider: AnalysisProvider):
        self._frame_extractor = FrameExtractor()
        self._nsfw_classifier = NSFWClassifier()
        self._violence_classifier = ViolenceClassifier()
        self._provider = provider

    def analyze(
        self,
        metadata: VideoMetadata,
        tier1_result: AnalysisResult,
    ) -> AnalysisResult:
        """Run Tier 2 visual analysis, building on Tier 1 results."""

        logger.info("Tier 2 starting for: %s", metadata.video_id)

        # Step 1: Extract frames
        frames = self._frame_extractor.extract(
            metadata.video_id,
            duration_seconds=metadata.duration_seconds,
        )

        if frames is None or frames.count == 0:
            logger.warning("No frames extracted for %s", metadata.video_id)
            # Return Tier 1 result with visual tier marked as attempted
            return AnalysisResult(
                video_id=metadata.video_id,
                verdict=tier1_result.verdict,
                scores=tier1_result.scores,
                tiers_completed=tier1_result.tiers_completed + [2],
                content_labels=tier1_result.content_labels,
                detected_issues=tier1_result.detected_issues
                    + ["frame_extraction_failed"],
                analysis_reasoning=tier1_result.analysis_reasoning
                    + " | Tier 2: frame extraction failed",
                confidence=tier1_result.confidence,
            )

        try:
            # Step 2: NSFW classification
            nsfw_results = self._nsfw_classifier.classify_frames(
                frames.frame_paths, frames.frame_timestamps
            )

            if self._nsfw_classifier.has_nsfw_content(nsfw_results):
                logger.info("NSFW content detected in %s — immediate reject", metadata.video_id)
                frames.cleanup()
                return AnalysisResult(
                    video_id=metadata.video_id,
                    verdict=Verdict.REJECT,
                    scores=tier1_result.scores.model_copy(
                        update={"violence_score": 10.0}
                    ),
                    tiers_completed=tier1_result.tiers_completed + [2],
                    content_labels=tier1_result.content_labels,
                    detected_issues=tier1_result.detected_issues + ["nsfw_content_detected"],
                    analysis_reasoning="Rejected: NSFW content detected in video frames",
                    confidence=0.98,
                )

            # Step 3: Violence and overstimulation detection
            violence_results = self._violence_classifier.classify_frames(
                frames.frame_paths, frames.frame_timestamps
            )
            overstim_score = self._violence_classifier.detect_overstimulation(
                frames.frame_paths, frames.frame_timestamps
            )

            worst_violence = max(
                (r.violence_score for r in violence_results), default=0.0
            )

            # Step 4: AI provider vision (if borderline or concerns found)
            needs_vision = (
                self._nsfw_classifier.has_concerning_content(nsfw_results)
                or worst_violence > 0.3
                or overstim_score > 0.4
                or tier1_result.verdict == Verdict.NEEDS_VISUAL_REVIEW
            )

            vision_result = None
            if needs_vision:
                logger.info("Sending frames to AI provider for %s", metadata.video_id)
                selected_paths = self._select_representative_frames(
                    frames.frame_paths, violence_results
                )

                # Read frames to bytes for the provider API
                frame_bytes = []
                for path in selected_paths:
                    try:
                        with open(path, "rb") as f:
                            frame_bytes.append(f.read())
                    except Exception as e:
                        logger.warning("Failed to read frame %s: %s", path, e)

                if frame_bytes:
                    context = (
                        f"Duration: {frames.total_duration / 60:.1f}min, "
                        f"sampled every 15s. "
                        f"Tier 1 scores: overstimulation="
                        f"{tier1_result.scores.overstimulation_score}, "
                        f"brainrot={tier1_result.scores.brainrot_score}, "
                        f"scariness={tier1_result.scores.scariness_score}, "
                        f"verdict={tier1_result.verdict.value}"
                    )
                    image_result = self._provider.analyze_image(
                        frame_bytes, title=metadata.title, context=context
                    )
                    vision_result = _adapt_image_result(image_result)

            # Step 5: Merge results
            return self._merge_results(
                metadata, tier1_result, nsfw_results,
                worst_violence, overstim_score, vision_result,
            )

        finally:
            frames.cleanup()

    def _select_representative_frames(
        self,
        frame_paths: list[str],
        violence_results,
    ) -> list[str]:
        """Select up to 12 diverse + high-concern frames."""
        if len(frame_paths) <= 12:
            return frame_paths

        selected = set()
        # First and last
        selected.add(0)
        selected.add(len(frame_paths) - 1)

        # Evenly spaced
        step = len(frame_paths) // 8
        for i in range(0, len(frame_paths), max(1, step)):
            selected.add(i)
            if len(selected) >= 10:
                break

        # Add highest violence score frames
        if violence_results:
            sorted_indices = sorted(
                range(len(violence_results)),
                key=lambda i: violence_results[i].violence_score,
                reverse=True,
            )
            for idx in sorted_indices[:2]:
                selected.add(idx)

        indices = sorted(selected)[:12]
        return [frame_paths[i] for i in indices if i < len(frame_paths)]

    def _merge_results(
        self,
        metadata: VideoMetadata,
        tier1: AnalysisResult,
        nsfw_results,
        worst_violence: float,
        overstim_score: float,
        vision_result: VisionResult | None,
    ) -> AnalysisResult:
        """Merge Tier 1 + Tier 2 analysis results."""

        # Start with Tier 1 scores
        scores = AnalysisScores(
            age_min_appropriate=tier1.scores.age_min_appropriate,
            age_max_appropriate=tier1.scores.age_max_appropriate,
            overstimulation_score=max(
                tier1.scores.overstimulation_score,
                overstim_score * 10,  # Convert 0-1 to 0-10
            ),
            educational_score=tier1.scores.educational_score,
            scariness_score=tier1.scores.scariness_score,
            brainrot_score=tier1.scores.brainrot_score,
            language_safety_score=tier1.scores.language_safety_score,
            violence_score=max(tier1.scores.violence_score, worst_violence * 10),
            ad_commercial_score=tier1.scores.ad_commercial_score,
        )

        issues = list(tier1.detected_issues)
        reasoning = tier1.analysis_reasoning

        # Update with AI provider vision results
        if vision_result:
            scores.overstimulation_score = max(
                scores.overstimulation_score,
                vision_result.visual_overstimulation,
            )
            scores.scariness_score = max(
                scores.scariness_score,
                vision_result.visual_scariness,
            )
            scores.violence_score = max(
                scores.violence_score,
                vision_result.visual_violence,
            )
            issues.extend(vision_result.visual_concerns)
            reasoning += f" | Tier 2 vision: {vision_result.reasoning}"

        # Determine verdict
        if vision_result and vision_result.visual_verdict == "REJECT":
            verdict = Verdict.REJECT
        elif worst_violence > 0.7:
            verdict = Verdict.REJECT
        elif vision_result and vision_result.visual_verdict == "APPROVE":
            verdict = Verdict.APPROVE
        elif tier1.verdict == Verdict.APPROVE:
            verdict = Verdict.APPROVE
        else:
            verdict = Verdict.NEEDS_AUDIO_REVIEW

        # Confidence boost from visual analysis
        confidence = min(0.95, tier1.confidence + 0.15)

        return AnalysisResult(
            video_id=metadata.video_id,
            verdict=verdict,
            scores=scores,
            tiers_completed=tier1.tiers_completed + [2],
            content_labels=tier1.content_labels,
            detected_issues=issues,
            analysis_reasoning=reasoning,
            confidence=confidence,
        )
