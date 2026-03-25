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
    piped_api_url: str = field(
        default_factory=lambda: os.getenv(
            "PIPED_API_URL", "https://pipedapi.kavin.rocks"
        )
    )

    # Claude API
    anthropic_api_key: str = field(
        default_factory=lambda: os.getenv("ANTHROPIC_API_KEY", "")
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


settings = Settings()
