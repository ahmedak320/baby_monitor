"""Google Gemini provider for content analysis."""

import json
import logging
import os

from providers.base_provider import (
    AnalysisProvider,
    ImageAnalysisResult,
    TextAnalysisResult,
)
from utils.provider_rate_limiter import get_rate_limiter

logger = logging.getLogger(__name__)

# Rate limiter for Gemini free tier (10 RPM, 1400 RPD)
_rate_limiter = get_rate_limiter("gemini")

ANALYSIS_PROMPT = """Analyze this YouTube video for child safety. Rate each dimension 1-10.

Title: {title}
Channel: {channel}
Description: {description}
Tags: {tags}
Duration: {duration_minutes} minutes
Transcript: {transcript}

Rate on these dimensions (1=worst, 10=best/safest):
- age_min_appropriate: minimum recommended age (integer 0-18)
- age_max_appropriate: maximum recommended age (integer 0-18)
- overstimulation_score: 1=calm, 10=extremely overstimulating
- educational_score: 1=no educational value, 10=highly educational
- scariness_score: 1=not scary, 10=terrifying
- brainrot_score: 1=quality content, 10=pure brainrot
- language_safety_score: 1=profanity, 10=clean
- ad_commercial_score: 1=no ads, 10=infomercial

Also provide:
- content_labels: list of labels (educational, music, nature, cartoon, etc.)
- detected_issues: list of concerns
- overall_verdict: APPROVE, REJECT, or NEEDS_VISUAL_REVIEW
- reasoning: brief explanation

Return valid JSON only."""


class GeminiProvider(AnalysisProvider):
    """Google Gemini-based content analysis."""

    def __init__(self):
        try:
            from google import genai

            api_key = os.getenv("GEMINI_API_KEY", "")
            if api_key:
                self._client = genai.Client(api_key=api_key)
            else:
                self._client = None
            self._model_name = "gemini-2.0-flash"
        except ImportError:
            logger.warning("google-genai not installed; Gemini provider unavailable")
            self._client = None
            self._model_name = None

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
        if self._client is None:
            return TextAnalysisResult(
                overall_verdict="NEEDS_VISUAL_REVIEW",
                reasoning="Gemini provider not available",
                provider_name="gemini",
            )

        prompt = ANALYSIS_PROMPT.format(
            title=title,
            channel=channel,
            description=description[:2000],
            tags=", ".join(tags[:20]),
            duration_minutes=round(duration_seconds / 60, 1),
            transcript=transcript[:15000],
        )

        try:
            _rate_limiter.wait_if_needed()
            response = self._client.models.generate_content(
                model=self._model_name, contents=prompt
            )
            _rate_limiter.record_request()
            logger.info("Gemini text analysis complete. %d requests remaining today.", _rate_limiter.remaining_today)
            raw_text = response.text.strip()

            # Parse JSON from response
            if raw_text.startswith("```"):
                raw_text = raw_text.split("```")[1]
                if raw_text.startswith("json"):
                    raw_text = raw_text[4:]

            data = json.loads(raw_text)

            return TextAnalysisResult(
                age_min_appropriate=data.get("age_min_appropriate", 0),
                age_max_appropriate=data.get("age_max_appropriate", 18),
                overstimulation_score=float(data.get("overstimulation_score", 5.0)),
                educational_score=float(data.get("educational_score", 5.0)),
                scariness_score=float(data.get("scariness_score", 5.0)),
                brainrot_score=float(data.get("brainrot_score", 5.0)),
                language_safety_score=float(data.get("language_safety_score", 5.0)),
                ad_commercial_score=float(data.get("ad_commercial_score", 5.0)),
                content_labels=data.get("content_labels", []),
                detected_issues=data.get("detected_issues", []),
                overall_verdict=data.get("overall_verdict", "NEEDS_VISUAL_REVIEW"),
                reasoning=data.get("reasoning", ""),
                confidence=0.82,
                cost_usd=0.001,  # Gemini Flash is very cheap
                provider_name="gemini",
            )
        except Exception as e:
            logger.error("Gemini text analysis failed: %s", e)
            return TextAnalysisResult(
                overall_verdict="NEEDS_VISUAL_REVIEW",
                reasoning="Gemini text analysis encountered an error",
                provider_name="gemini",
            )

    def analyze_image(
        self,
        frames: list[bytes],
        title: str = "",
        context: str = "",
    ) -> ImageAnalysisResult:
        if self._client is None:
            return ImageAnalysisResult(
                reasoning="Gemini provider not available",
                provider_name="gemini",
            )

        try:
            import PIL.Image
            import io

            parts = [f"Analyze these video frames from '{title}' for child safety. "
                     "Rate violence, nudity, scariness, and overstimulation 1-10. "
                     "Return JSON with: violence_score, nudity_score, scariness_score, "
                     "overstimulation_score, overall_verdict (APPROVE/REJECT), reasoning."]

            for frame_data in frames[:4]:  # Max 4 frames
                img = PIL.Image.open(io.BytesIO(frame_data))
                parts.append(img)

            _rate_limiter.wait_if_needed()
            response = self._client.models.generate_content(
                model=self._model_name, contents=parts
            )
            _rate_limiter.record_request()
            logger.info("Gemini vision analysis complete. %d requests remaining today.", _rate_limiter.remaining_today)
            raw_text = response.text.strip()
            if raw_text.startswith("```"):
                raw_text = raw_text.split("```")[1]
                if raw_text.startswith("json"):
                    raw_text = raw_text[4:]

            data = json.loads(raw_text)
            return ImageAnalysisResult(
                violence_score=float(data.get("violence_score", 1.0)),
                nudity_score=float(data.get("nudity_score", 1.0)),
                scariness_score=float(data.get("scariness_score", 1.0)),
                overstimulation_score=float(data.get("overstimulation_score", 1.0)),
                overall_verdict=data.get("overall_verdict", "APPROVE"),
                reasoning=data.get("reasoning", ""),
                confidence=0.85,
                cost_usd=0.005,
                provider_name="gemini",
            )
        except Exception as e:
            logger.error("Gemini image analysis failed: %s", e)
            return ImageAnalysisResult(
                reasoning="Gemini vision analysis encountered an error",
                provider_name="gemini",
            )

    def get_provider_name(self) -> str:
        return "gemini"

    def get_cost_per_text_analysis(self) -> float:
        return 0.001

    def get_cost_per_image_analysis(self) -> float:
        return 0.005
