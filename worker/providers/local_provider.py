"""Local model provider — calls a local HTTP endpoint (e.g., Ollama)."""

import json
import logging
import os

import httpx

from providers.base_provider import (
    AnalysisProvider,
    ImageAnalysisResult,
    TextAnalysisResult,
)

logger = logging.getLogger(__name__)


class LocalProvider(AnalysisProvider):
    """Local model provider using an Ollama-compatible API."""

    def __init__(self):
        self._base_url = os.getenv("LOCAL_MODEL_URL", "http://localhost:11434")
        self._model = os.getenv("LOCAL_MODEL_NAME", "llama3.2")

        from urllib.parse import urlparse
        parsed = urlparse(self._base_url)
        if parsed.hostname not in ("localhost", "127.0.0.1", "::1"):
            raise ValueError(f"LOCAL_MODEL_URL must point to localhost, got: {parsed.hostname}")

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
        prompt = (
            f"Analyze this YouTube video for child safety.\n"
            f"Title: {title}\nChannel: {channel}\n"
            f"Description: {description[:1000]}\n"
            f"Tags: {', '.join(tags[:10])}\n"
            f"Duration: {duration_seconds // 60} minutes\n"
            f"Transcript: {transcript[:5000]}\n\n"
            "Return JSON with: age_min_appropriate (int), age_max_appropriate (int), "
            "overstimulation_score (1-10), educational_score (1-10), scariness_score (1-10), "
            "brainrot_score (1-10), language_safety_score (1-10), ad_commercial_score (1-10), "
            "content_labels (list), detected_issues (list), "
            "overall_verdict (APPROVE/REJECT/NEEDS_VISUAL_REVIEW), reasoning (string)."
        )

        try:
            response = httpx.post(
                f"{self._base_url}/api/generate",
                json={"model": self._model, "prompt": prompt, "stream": False},
                timeout=120.0,
            )
            response.raise_for_status()
            raw_text = response.json().get("response", "")

            # Try to parse JSON
            if "{" in raw_text:
                json_str = raw_text[raw_text.index("{"):raw_text.rindex("}") + 1]
                data = json.loads(json_str)
            else:
                data = {}

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
                confidence=0.70,
                cost_usd=0.0,  # Local model = free
                provider_name="local",
            )
        except Exception as e:
            logger.error("Local model analysis failed: %s", e)
            return TextAnalysisResult(
                overall_verdict="NEEDS_VISUAL_REVIEW",
                reasoning="Local model analysis encountered an error",
                provider_name="local",
            )

    def analyze_image(
        self,
        frames: list[bytes],
        title: str = "",
        context: str = "",
    ) -> ImageAnalysisResult:
        # Most local models don't support vision yet; return neutral result
        logger.info("Local provider does not support image analysis")
        return ImageAnalysisResult(
            overall_verdict="NEEDS_VISUAL_REVIEW",
            reasoning="Local model does not support vision; manual review needed",
            confidence=0.3,
            cost_usd=0.0,
            provider_name="local",
        )

    def get_provider_name(self) -> str:
        return "local"

    def get_cost_per_text_analysis(self) -> float:
        return 0.0

    def get_cost_per_image_analysis(self) -> float:
        return 0.0
