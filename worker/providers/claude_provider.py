"""Claude (Anthropic) provider for content analysis."""

import base64
import json
import logging

import anthropic

from config import settings
from providers.base_provider import (
    AnalysisProvider,
    ImageAnalysisResult,
    TextAnalysisResult,
)

logger = logging.getLogger(__name__)

VISION_PROMPT = """Analyze these video frames from a children's YouTube video for safety.
{context}

Rate violence, nudity, scariness, and overstimulation 1-10 (1=safest, 10=worst).
Return valid JSON only:
{{"violence_score": 1.0, "nudity_score": 1.0, "scariness_score": 1.0, "overstimulation_score": 1.0, "overall_verdict": "APPROVE", "reasoning": "..."}}"""


class ClaudeProvider(AnalysisProvider):
    """Claude-based content analysis using Haiku."""

    def __init__(self):
        from analyzers.haiku_text_analyzer import HaikuTextAnalyzer

        self._text_analyzer = HaikuTextAnalyzer()
        self._client = anthropic.Anthropic(api_key=settings.anthropic_api_key)

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
        content = []
        for frame_data in frames[:12]:
            try:
                img_data = base64.standard_b64encode(frame_data).decode("utf-8")
                content.append({
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": img_data,
                    },
                })
            except Exception as e:
                logger.warning("Failed to encode frame: %s", e)

        if not content:
            return ImageAnalysisResult(
                reasoning="No frames available for analysis",
                provider_name="claude",
            )

        ctx = f"Title: '{title}'"
        if context:
            ctx += f"\n{context}"
        content.append({"type": "text", "text": VISION_PROMPT.format(context=ctx)})

        try:
            response = self._client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=500,
                messages=[{"role": "user", "content": content}],
            )
            raw_text = response.content[0].text.strip()
            data = json.loads(raw_text)

            return ImageAnalysisResult(
                violence_score=float(data.get("violence_score", 1.0)),
                nudity_score=float(data.get("nudity_score", 1.0)),
                scariness_score=float(data.get("scariness_score", 1.0)),
                overstimulation_score=float(data.get("overstimulation_score", 1.0)),
                overall_verdict=data.get("overall_verdict", "APPROVE"),
                reasoning=data.get("reasoning", ""),
                confidence=0.90,
                cost_usd=(response.usage.input_tokens * 0.25
                          + response.usage.output_tokens * 1.25) / 1_000_000,
                provider_name="claude",
            )
        except Exception as e:
            logger.error("Claude vision analysis failed: %s", e)
            return ImageAnalysisResult(
                reasoning="Vision analysis encountered an error",
                provider_name="claude",
            )

    def get_provider_name(self) -> str:
        return "claude"

    def get_cost_per_text_analysis(self) -> float:
        return 0.003

    def get_cost_per_image_analysis(self) -> float:
        return 0.015
