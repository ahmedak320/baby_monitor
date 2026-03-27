"""Abstract base class for AI analysis providers."""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class TextAnalysisResult:
    """Standardized result from any AI provider's text analysis."""

    age_min_appropriate: int = 0
    age_max_appropriate: int = 18
    overstimulation_score: float = 5.0
    educational_score: float = 5.0
    scariness_score: float = 5.0
    brainrot_score: float = 5.0
    language_safety_score: float = 5.0
    ad_commercial_score: float = 5.0
    content_labels: list[str] = field(default_factory=list)
    detected_issues: list[str] = field(default_factory=list)
    overall_verdict: str = "NEEDS_VISUAL_REVIEW"
    reasoning: str = ""
    confidence: float = 0.5
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float = 0.0
    provider_name: str = ""


@dataclass
class ImageAnalysisResult:
    """Standardized result from visual frame analysis."""

    violence_score: float = 1.0
    nudity_score: float = 1.0
    scariness_score: float = 1.0
    overstimulation_score: float = 1.0
    overall_verdict: str = "APPROVE"
    reasoning: str = ""
    confidence: float = 0.5
    cost_usd: float = 0.0
    provider_name: str = ""


class AnalysisProvider(ABC):
    """Abstract interface for AI-powered content analysis."""

    @abstractmethod
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
        """Analyze video metadata + transcript text."""
        ...

    @abstractmethod
    def analyze_image(
        self,
        frames: list[bytes],
        title: str = "",
        context: str = "",
    ) -> ImageAnalysisResult:
        """Analyze extracted video frames."""
        ...

    @abstractmethod
    def get_provider_name(self) -> str:
        """Return the provider name (e.g., 'claude', 'gemini')."""
        ...

    @abstractmethod
    def get_cost_per_text_analysis(self) -> float:
        """Estimated cost per text analysis in USD."""
        ...

    @abstractmethod
    def get_cost_per_image_analysis(self) -> float:
        """Estimated cost per image analysis in USD."""
        ...
