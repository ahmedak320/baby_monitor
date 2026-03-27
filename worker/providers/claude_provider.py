"""Claude (Anthropic) provider — wraps existing Haiku analyzers."""

import logging

from analyzers.haiku_text_analyzer import HaikuTextAnalyzer
from analyzers.haiku_vision_analyzer import HaikuVisionAnalyzer
from providers.base_provider import (
    AnalysisProvider,
    ImageAnalysisResult,
    TextAnalysisResult,
)

logger = logging.getLogger(__name__)


class ClaudeProvider(AnalysisProvider):
    """Claude-based content analysis using Haiku for text and Sonnet for vision."""

    def __init__(self):
        self._text_analyzer = HaikuTextAnalyzer()
        self._vision_analyzer = HaikuVisionAnalyzer()

    def analyze_text(
        self,
        title: str,
        channel: str,
        description: str,
        tags: list[str],
        duration_seconds: int,
        transcript: str,
        toxicity_summary: str = "",
    ) -> TextAnalysisResult:
        haiku_result = self._text_analyzer.analyze(
            title=title,
            channel=channel,
            description=description,
            tags=tags,
            duration_seconds=duration_seconds,
            transcript=transcript,
            toxicity_summary=toxicity_summary,
        )

        return TextAnalysisResult(
            age_min_appropriate=haiku_result.age_min_appropriate,
            age_max_appropriate=haiku_result.age_max_appropriate,
            overstimulation_score=haiku_result.overstimulation_score,
            educational_score=haiku_result.educational_score,
            scariness_score=haiku_result.scariness_score,
            brainrot_score=haiku_result.brainrot_score,
            language_safety_score=haiku_result.language_safety_score,
            ad_commercial_score=haiku_result.ad_commercial_score,
            content_labels=haiku_result.content_labels,
            detected_issues=haiku_result.detected_issues,
            overall_verdict=haiku_result.overall_verdict,
            reasoning=haiku_result.reasoning,
            confidence=0.85,
            input_tokens=haiku_result.input_tokens,
            output_tokens=haiku_result.output_tokens,
            cost_usd=haiku_result.estimated_cost,
            provider_name="claude",
        )

    def analyze_image(
        self,
        frames: list[bytes],
        title: str = "",
        context: str = "",
    ) -> ImageAnalysisResult:
        vision_result = self._vision_analyzer.analyze(
            frames=frames,
            title=title,
            context=context,
        )

        return ImageAnalysisResult(
            violence_score=getattr(vision_result, "violence_score", 1.0),
            nudity_score=getattr(vision_result, "nudity_score", 1.0),
            scariness_score=getattr(vision_result, "scariness_score", 1.0),
            overstimulation_score=getattr(
                vision_result, "overstimulation_score", 1.0
            ),
            overall_verdict=getattr(vision_result, "overall_verdict", "APPROVE"),
            reasoning=getattr(vision_result, "reasoning", ""),
            confidence=0.90,
            cost_usd=getattr(vision_result, "estimated_cost", 0.015),
            provider_name="claude",
        )

    def get_provider_name(self) -> str:
        return "claude"

    def get_cost_per_text_analysis(self) -> float:
        return 0.003

    def get_cost_per_image_analysis(self) -> float:
        return 0.015
