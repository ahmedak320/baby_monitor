"""Worker configuration loaded from environment variables."""

import os
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv

# Load .env from worker directory or project root
env_path = Path(__file__).parent / ".env"
if not env_path.exists():
    env_path = Path(__file__).parent.parent / ".env"
load_dotenv(env_path)


@dataclass
class Settings:
    """Application settings from environment variables."""

    # Supabase
    supabase_url: str = field(
        default_factory=lambda: os.getenv("SUPABASE_URL", "")
    )
    supabase_service_key: str = field(
        default_factory=lambda: os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    )

    # YouTube
    youtube_api_key: str = field(
        default_factory=lambda: os.getenv("YOUTUBE_API_KEY", "")
    )
    youtube_api_keys: list[str] = field(
        default_factory=lambda: [
            k.strip()
            for k in os.getenv(
                "YOUTUBE_API_KEYS", os.getenv("YOUTUBE_API_KEY", "")
            ).split(",")
            if k.strip()
        ]
    )
    piped_api_url: str = field(
        default_factory=lambda: os.getenv(
            "PIPED_API_URL", "https://pipedapi.kavin.rocks"
        )
    )
    piped_instances: list[str] = field(
        default_factory=lambda: [
            u.strip()
            for u in os.getenv(
                "PIPED_INSTANCES",
                os.getenv("PIPED_API_URL", "https://pipedapi.kavin.rocks"),
            ).split(",")
            if u.strip()
        ]
    )

    # AI Providers
    anthropic_api_key: str = field(
        default_factory=lambda: os.getenv("ANTHROPIC_API_KEY", "")
    )
    gemini_api_key: str = field(
        default_factory=lambda: os.getenv("GEMINI_API_KEY", "")
    )
    openai_api_key: str = field(
        default_factory=lambda: os.getenv("OPENAI_API_KEY", "")
    )
    ai_provider: str = field(
        default_factory=lambda: os.getenv("AI_PROVIDER", "claude")
    )
    local_model_url: str = field(
        default_factory=lambda: os.getenv("LOCAL_MODEL_URL", "http://localhost:11434")
    )

    # Worker settings
    poll_interval_seconds: int = 10
    max_concurrent_analyses: int = 3
    temp_dir: str = "/tmp/baby_monitor_worker"
    worker_api_key: str = field(
        default_factory=lambda: os.getenv("WORKER_API_KEY", "")
    )
    api_port: int = 8000

    # Tier thresholds
    tier1_confidence_threshold: float = 0.85
    tier2_confidence_threshold: float = 0.90

    def __post_init__(self) -> None:
        """Ensure temp directory exists with restricted permissions."""
        os.makedirs(self.temp_dir, mode=0o700, exist_ok=True)


settings = Settings()
