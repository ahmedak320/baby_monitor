"""OpenAI provider for content analysis."""

import base64
import json
import logging
import os

from providers.base_provider import (
    AnalysisProvider,
    ImageAnalysisResult,
    TextAnalysisResult,
)

logger = logging.getLogger(__name__)

ANALYSIS_PROMPT = """Analyze this YouTube video for child safety. Rate each dimension 1-10.

Title: {title}
Channel: {channel}
Description: {description}
Tags: {tags}
Duration: {duration_minutes} minutes
Transcript: {transcript}

Rate (1=worst, 10=best/safest): age_min_appropriate (0-18), age_max_appropriate (0-18), overstimulation_score, educational_score, scariness_score, brainrot_score, language_safety_score, ad_commercial_score.

Also: content_labels (list), detected_issues (list), overall_verdict (APPROVE/REJECT/NEEDS_VISUAL_REVIEW), reasoning.

Return valid JSON only."""


class OpenAIProvider(AnalysisProvider):
    """OpenAI-based content analysis using GPT-4o-mini."""

    def __init__(self):
        try:
            from openai import OpenAI

            api_key = os.getenv("OPENAI_API_KEY", "")
            self._client = OpenAI(api_key=api_key) if api_key else None
        except ImportError:
            logger.warning("openai not installed; OpenAI provider unavailable")
            self._client = None

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
                reasoning="OpenAI provider not available",
                provider_name="openai",
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
            response = self._client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=1000,
                response_format={"type": "json_object"},
            )

            raw_text = response.choices[0].message.content.strip()
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
                confidence=0.83,
                input_tokens=response.usage.prompt_tokens,
                output_tokens=response.usage.completion_tokens,
                cost_usd=0.002,
                provider_name="openai",
            )
        except Exception as e:
            logger.error("OpenAI text analysis failed: %s", e)
            return TextAnalysisResult(
                overall_verdict="NEEDS_VISUAL_REVIEW",
                reasoning="OpenAI text analysis encountered an error",
                provider_name="openai",
            )

    def analyze_image(
        self,
        frames: list[bytes],
        title: str = "",
        context: str = "",
    ) -> ImageAnalysisResult:
        if self._client is None:
            return ImageAnalysisResult(
                reasoning="OpenAI provider not available",
                provider_name="openai",
            )

        try:
            content = [
                {
                    "type": "text",
                    "text": f"Analyze these frames from '{title}' for child safety. "
                    "Rate violence, nudity, scariness, overstimulation 1-10. "
                    "Return JSON: violence_score, nudity_score, scariness_score, "
                    "overstimulation_score, overall_verdict (APPROVE/REJECT), reasoning.",
                }
            ]

            for frame_data in frames[:4]:
                b64 = base64.b64encode(frame_data).decode()
                content.append(
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{b64}"},
                    }
                )

            response = self._client.chat.completions.create(
                model="gpt-4o",
                messages=[{"role": "user", "content": content}],
                max_tokens=500,
            )

            raw_text = response.choices[0].message.content.strip()
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
                confidence=0.88,
                cost_usd=0.01,
                provider_name="openai",
            )
        except Exception as e:
            logger.error("OpenAI image analysis failed: %s", e)
            return ImageAnalysisResult(
                reasoning="OpenAI vision analysis encountered an error",
                provider_name="openai",
            )

    def get_provider_name(self) -> str:
        return "openai"

    def get_cost_per_text_analysis(self) -> float:
        return 0.002

    def get_cost_per_image_analysis(self) -> float:
        return 0.01
