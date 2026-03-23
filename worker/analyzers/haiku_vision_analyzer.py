"""Claude Haiku vision analysis for frame-based content review."""

import base64
import json
import logging
from dataclasses import dataclass

import anthropic

from config import settings

logger = logging.getLogger(__name__)

VISION_PROMPT = """Analyze these frames sampled from a children's YouTube video.
Frames are sampled every {interval}s from a {duration}min video.

Previously, text analysis scored it as:
- Overstimulation: {overstim}/10, Brainrot: {brainrot}/10, Scariness: {scary}/10
- Verdict from text: {text_verdict}

Look for:
1. Overstimulating visuals (rapid color changes, flashing, chaotic scenes)
2. Scary imagery (monsters, dark themes, jump-scare setups, creepy characters)
3. Age-inappropriate themes or imagery
4. Elsagate-style content (disturbing content disguised as kids content)
5. Quality of animation/production
6. Violence or aggressive behavior

Return valid JSON only:
{{"visual_overstimulation": 3.0, "visual_scariness": 2.0, "visual_violence": 1.0, "visual_quality": 7.0, "visual_concerns": [], "visual_verdict": "APPROVE", "reasoning": "..."}}

Scores are 1-10 where 1=safest and 10=most concerning (except quality: 1=poor, 10=excellent)."""


@dataclass
class HaikuVisionResult:
    """Result from Claude Haiku vision analysis."""

    visual_overstimulation: float = 5.0
    visual_scariness: float = 5.0
    visual_violence: float = 1.0
    visual_quality: float = 5.0
    visual_concerns: list[str] = None
    visual_verdict: str = "APPROVE"
    reasoning: str = ""
    input_tokens: int = 0
    output_tokens: int = 0

    def __post_init__(self):
        if self.visual_concerns is None:
            self.visual_concerns = []

    @property
    def estimated_cost(self) -> float:
        return (self.input_tokens * 0.25 + self.output_tokens * 1.25) / 1_000_000


class HaikuVisionAnalyzer:
    """Use Claude Haiku vision to analyze video frames."""

    def __init__(self):
        self._client = anthropic.Anthropic(api_key=settings.anthropic_api_key)

    def analyze(
        self,
        frame_paths: list[str],
        total_duration_minutes: float,
        sample_interval_seconds: int,
        text_scores: dict | None = None,
    ) -> HaikuVisionResult:
        """Analyze a selection of frames via Claude Haiku vision.

        Args:
            frame_paths: Paths to frame images (send up to 12)
            total_duration_minutes: Video duration
            sample_interval_seconds: Interval between frames
            text_scores: Optional dict from Tier 1 for context
        """
        # Limit to 12 frames for cost control
        selected = frame_paths[:12]

        # Build message with images
        content = []
        for path in selected:
            try:
                with open(path, "rb") as f:
                    img_data = base64.standard_b64encode(f.read()).decode("utf-8")
                content.append({
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": img_data,
                    },
                })
            except Exception as e:
                logger.warning("Failed to read frame %s: %s", path, e)

        if not content:
            logger.error("No frames could be loaded")
            return HaikuVisionResult(
                visual_verdict="APPROVE",
                reasoning="No frames available for analysis",
            )

        # Add text prompt
        ts = text_scores or {}
        prompt = VISION_PROMPT.format(
            interval=sample_interval_seconds,
            duration=round(total_duration_minutes, 1),
            overstim=ts.get("overstimulation_score", "N/A"),
            brainrot=ts.get("brainrot_score", "N/A"),
            scary=ts.get("scariness_score", "N/A"),
            text_verdict=ts.get("verdict", "N/A"),
        )
        content.append({"type": "text", "text": prompt})

        try:
            response = self._client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=500,
                messages=[{"role": "user", "content": content}],
            )

            raw_text = response.content[0].text.strip()
            parsed = json.loads(raw_text)

            result = HaikuVisionResult(
                visual_overstimulation=float(parsed.get("visual_overstimulation", 5)),
                visual_scariness=float(parsed.get("visual_scariness", 5)),
                visual_violence=float(parsed.get("visual_violence", 1)),
                visual_quality=float(parsed.get("visual_quality", 5)),
                visual_concerns=parsed.get("visual_concerns", []),
                visual_verdict=parsed.get("visual_verdict", "APPROVE"),
                reasoning=parsed.get("reasoning", ""),
                input_tokens=response.usage.input_tokens,
                output_tokens=response.usage.output_tokens,
            )

            logger.info(
                "Haiku vision: verdict=%s, cost=$%.4f, frames=%d",
                result.visual_verdict,
                result.estimated_cost,
                len(selected),
            )

            return result

        except json.JSONDecodeError as e:
            logger.error("Haiku vision JSON parse error: %s", e)
            return HaikuVisionResult(reasoning=f"JSON parse error: {e}")
        except Exception as e:
            logger.error("Haiku vision analysis failed: %s", e)
            return HaikuVisionResult(reasoning=f"Vision error: {e}")
