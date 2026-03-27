"""Factory for creating AI analysis providers."""

import logging
import os

from providers.base_provider import AnalysisProvider

logger = logging.getLogger(__name__)


def get_provider(name: str | None = None) -> AnalysisProvider:
    """Create an analysis provider by name.

    Args:
        name: Provider name ('claude', 'gemini', 'openai', 'local').
              Defaults to AI_PROVIDER env var or 'claude'.

    Returns:
        An AnalysisProvider instance.
    """
    provider_name = name or os.getenv("AI_PROVIDER", "claude")
    provider_name = provider_name.lower().strip()

    if provider_name == "claude":
        from providers.claude_provider import ClaudeProvider
        return ClaudeProvider()
    elif provider_name == "gemini":
        from providers.gemini_provider import GeminiProvider
        return GeminiProvider()
    elif provider_name == "openai":
        from providers.openai_provider import OpenAIProvider
        return OpenAIProvider()
    elif provider_name == "local":
        from providers.local_provider import LocalProvider
        return LocalProvider()
    else:
        logger.warning("Unknown provider '%s', falling back to Claude", provider_name)
        from providers.claude_provider import ClaudeProvider
        return ClaudeProvider()
