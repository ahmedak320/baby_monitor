"""Tests for the AI provider abstraction layer."""

import pytest
from providers.base_provider import AnalysisProvider, TextAnalysisResult, ImageAnalysisResult
from providers.provider_factory import get_provider


class TestProviderFactory:
    def test_default_provider_is_claude(self, monkeypatch):
        monkeypatch.delenv("AI_PROVIDER", raising=False)
        provider = get_provider("claude")
        assert provider.get_provider_name() == "claude"

    def test_gemini_provider_creation(self):
        provider = get_provider("gemini")
        assert provider.get_provider_name() == "gemini"

    def test_openai_provider_creation(self):
        provider = get_provider("openai")
        assert provider.get_provider_name() == "openai"

    def test_local_provider_creation(self):
        provider = get_provider("local")
        assert provider.get_provider_name() == "local"

    def test_unknown_provider_falls_back_to_claude(self):
        provider = get_provider("unknown_provider")
        assert provider.get_provider_name() == "claude"

    def test_case_insensitive_provider_name(self):
        provider = get_provider("CLAUDE")
        assert provider.get_provider_name() == "claude"


class TestTextAnalysisResult:
    def test_default_values(self):
        result = TextAnalysisResult()
        assert result.age_min_appropriate == 0
        assert result.age_max_appropriate == 18
        assert result.confidence == 0.5
        assert result.content_labels == []
        assert result.detected_issues == []

    def test_custom_values(self):
        result = TextAnalysisResult(
            age_min_appropriate=3,
            age_max_appropriate=8,
            overstimulation_score=2.5,
            overall_verdict="APPROVE",
            confidence=0.9,
            content_labels=["educational"],
            provider_name="claude",
        )
        assert result.age_min_appropriate == 3
        assert result.overall_verdict == "APPROVE"
        assert result.provider_name == "claude"
        assert "educational" in result.content_labels


class TestImageAnalysisResult:
    def test_default_values(self):
        result = ImageAnalysisResult()
        assert result.violence_score == 1.0
        assert result.overall_verdict == "APPROVE"
        assert result.confidence == 0.5

    def test_custom_values(self):
        result = ImageAnalysisResult(
            violence_score=8.0,
            overall_verdict="REJECT",
            reasoning="High violence detected",
        )
        assert result.violence_score == 8.0
        assert result.overall_verdict == "REJECT"


class TestLocalProvider:
    def test_image_analysis_returns_review_needed(self):
        provider = get_provider("local")
        result = provider.analyze_image(frames=[], title="test")
        # Local provider doesn't support vision
        assert result.overall_verdict == "NEEDS_VISUAL_REVIEW"
        assert result.cost_usd == 0.0

    def test_cost_is_zero(self):
        provider = get_provider("local")
        assert provider.get_cost_per_text_analysis() == 0.0
        assert provider.get_cost_per_image_analysis() == 0.0
