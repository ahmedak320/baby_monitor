"""Claude Haiku text analysis for nuanced content reasoning."""

import json
import logging
from dataclasses import dataclass

from config import settings
from utils.score_validation import safe_float, safe_int

logger = logging.getLogger(__name__)

ANALYSIS_PROMPT = """Analyze this YouTube video for child safety. Rate each dimension 1-10.

Title: {title}
Channel: {channel}
Description: {description}
Tags: {tags}
Duration: {duration_minutes} minutes
Transcript (full): {transcript}

Pre-computed toxicity scores: {toxicity_summary}

Rate on these dimensions (1=worst, 10=best/safest):
- age_min_appropriate: minimum recommended age (integer 0-18)
- age_max_appropriate: maximum recommended age (integer 0-18)
- overstimulation_score: 1=calm/gentle, 10=extremely overstimulating (rapid editing, flashing)
- educational_score: 1=no educational value, 10=highly educational
- scariness_score: 1=not scary at all, 10=terrifying (monsters, dark themes, jump scares)
- brainrot_score: 1=quality content, 10=pure brainrot (repetitive catchphrases, mindless)
- language_safety_score: 1=profanity/adult language, 10=perfectly clean
- ad_commercial_score: 1=no ads/product placement, 10=infomercial/toy unboxing spam

Also provide:
- content_labels: list of applicable labels (e.g., "educational", "music", "nature", "cartoon", "storytime", "soothing", "creative", "fun")
- detected_issues: list of specific concerns (e.g., "loud_screaming_at_2m30s", "brainrot_repetitive_catchphrase")
- overall_verdict: APPROVE, REJECT, or NEEDS_VISUAL_REVIEW
- reasoning: brief explanation of your assessment

Return valid JSON only, no markdown:
{{"age_min_appropriate": 3, "age_max_appropriate": 8, "overstimulation_score": 3.0, "educational_score": 7.0, "scariness_score": 2.0, "brainrot_score": 2.0, "language_safety_score": 9.0, "ad_commercial_score": 2.0, "content_labels": ["educational", "nature"], "detected_issues": [], "overall_verdict": "APPROVE", "reasoning": "..."}}"""


@dataclass
class HaikuTextResult:
    """Result from Claude Haiku text analysis."""

    age_min_appropriate: int = 0
    age_max_appropriate: int = 18
    overstimulation_score: float = 5.0
    educational_score: float = 5.0
    scariness_score: float = 5.0
    brainrot_score: float = 5.0
    language_safety_score: float = 5.0
    ad_commercial_score: float = 5.0
    content_labels: list[str] = None
    detected_issues: list[str] = None
    overall_verdict: str = "NEEDS_VISUAL_REVIEW"
    reasoning: str = ""
    input_tokens: int = 0
    output_tokens: int = 0

    def __post_init__(self):
        if self.content_labels is None:
            self.content_labels = []
        if self.detected_issues is None:
            self.detected_issues = []

    @property
    def estimated_cost(self) -> float:
        """Estimate cost based on Claude Haiku pricing."""
        # Haiku: $0.25/MTok input, $1.25/MTok output
        return (self.input_tokens * 0.25 + self.output_tokens * 1.25) / 1_000_000


class HaikuTextAnalyzer:
    """Use Claude Haiku for nuanced text-based content analysis."""

    def __init__(self):
        try:
            import anthropic

            api_key = settings.anthropic_api_key
            self._client = anthropic.Anthropic(api_key=api_key) if api_key else None
        except ImportError:
            logger.warning("anthropic not installed; HaikuTextAnalyzer unavailable")
            self._client = None

    def analyze(
        self,
        title: str,
        channel: str,
        description: str,
        tags: list[str],
        duration_seconds: int,
        transcript: str,
        toxicity_summary: str = "",
    ) -> HaikuTextResult:
        """Analyze video metadata + transcript via Claude Haiku."""
        if self._client is None:
            return HaikuTextResult(
                overall_verdict="NEEDS_VISUAL_REVIEW",
                reasoning="Claude provider not available",
            )

        # Truncate transcript to avoid excessive token usage
        max_transcript_len = 15000
        truncated_transcript = transcript[:max_transcript_len]
        if len(transcript) > max_transcript_len:
            truncated_transcript += f"\n... [truncated, full transcript is {len(transcript)} chars]"

        prompt = ANALYSIS_PROMPT.format(
            title=title,
            channel=channel,
            description=description[:2000],
            tags=", ".join(tags[:20]),
            duration_minutes=round(duration_seconds / 60, 1),
            transcript=truncated_transcript,
            toxicity_summary=toxicity_summary or "N/A",
        )

        try:
            response = self._client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=1000,
                messages=[{"role": "user", "content": prompt}],
            )

            raw_text = response.content[0].text.strip()
            input_tokens = response.usage.input_tokens
            output_tokens = response.usage.output_tokens

            # Parse JSON response
            parsed = json.loads(raw_text)

            result = HaikuTextResult(
                age_min_appropriate=safe_int(parsed.get("age_min_appropriate", 0), default=0),
                age_max_appropriate=safe_int(parsed.get("age_max_appropriate", 18), default=18),
                overstimulation_score=safe_float(parsed.get("overstimulation_score", 5), default=5.0, min_val=1.0),
                educational_score=safe_float(parsed.get("educational_score", 5), default=5.0, min_val=1.0),
                scariness_score=safe_float(parsed.get("scariness_score", 5), default=5.0, min_val=1.0),
                brainrot_score=safe_float(parsed.get("brainrot_score", 5), default=5.0, min_val=1.0),
                language_safety_score=safe_float(parsed.get("language_safety_score", 5), default=5.0, min_val=1.0),
                ad_commercial_score=safe_float(parsed.get("ad_commercial_score", 5), default=5.0, min_val=1.0),
                content_labels=parsed.get("content_labels", []),
                detected_issues=parsed.get("detected_issues", []),
                overall_verdict=parsed.get("overall_verdict", "NEEDS_VISUAL_REVIEW"),
                reasoning=parsed.get("reasoning", ""),
                input_tokens=input_tokens,
                output_tokens=output_tokens,
            )

            logger.info(
                "Haiku text analysis: verdict=%s, cost=$%.4f, tokens=%d/%d",
                result.overall_verdict,
                result.estimated_cost,
                input_tokens,
                output_tokens,
            )

            return result

        except json.JSONDecodeError as e:
            logger.error("Failed to parse Haiku JSON response: %s", e)
            return HaikuTextResult(
                overall_verdict="NEEDS_VISUAL_REVIEW",
                reasoning="Text analysis encountered a parsing error",
            )
        except Exception as e:
            logger.error("Haiku text analysis failed: %s", e)
            return HaikuTextResult(
                overall_verdict="NEEDS_VISUAL_REVIEW",
                reasoning="Text analysis encountered an error",
            )
