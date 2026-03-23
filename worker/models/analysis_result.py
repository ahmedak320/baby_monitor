"""Pydantic models for analysis results."""

from enum import Enum
from pydantic import BaseModel


class Verdict(str, Enum):
    APPROVE = "approve"
    REJECT = "reject"
    NEEDS_VISUAL_REVIEW = "needs_visual_review"
    NEEDS_AUDIO_REVIEW = "needs_audio_review"
    PENDING = "pending"


class AnalysisScores(BaseModel):
    """Safety scores for a video (1-10 scale)."""

    age_min_appropriate: int = 0
    age_max_appropriate: int = 18
    overstimulation_score: float = 0.0
    educational_score: float = 0.0
    scariness_score: float = 0.0
    brainrot_score: float = 0.0
    language_safety_score: float = 10.0
    violence_score: float = 0.0
    ad_commercial_score: float = 0.0
    audio_safety_score: float = 10.0


class AnalysisResult(BaseModel):
    """Complete result of video analysis."""

    video_id: str
    verdict: Verdict
    scores: AnalysisScores = AnalysisScores()
    tiers_completed: list[int] = []
    content_labels: list[str] = []
    detected_issues: list[str] = []
    analysis_reasoning: str = ""
    confidence: float = 0.0
