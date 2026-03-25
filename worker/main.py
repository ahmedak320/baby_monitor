"""Baby Monitor AI Analysis Worker

Main entry point for the video analysis pipeline.
Polls the Supabase analysis_queue and processes videos through
a 4-tier analysis funnel.
"""

import asyncio
import logging
import os
import sys

from supabase import create_client

from config import settings
from discovery.auto_discovery import AutoDiscovery
from queue.consumer import QueueConsumer

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)

logger = logging.getLogger(__name__)


async def main() -> None:
    """Main worker loop."""
    logger.info("Starting Baby Monitor AI Worker...")
    logger.info("Supabase URL: %s", settings.supabase_url)
    logger.info("Temp dir: %s", settings.temp_dir)

    # Ensure temp directory exists
    os.makedirs(settings.temp_dir, exist_ok=True)

    # Validate config
    if not settings.supabase_url or not settings.supabase_service_key:
        logger.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required")
        sys.exit(1)

    if not settings.anthropic_api_key:
        logger.warning("ANTHROPIC_API_KEY not set — Claude Haiku analysis disabled")

    consumer = QueueConsumer()

    # Set up auto-discovery
    supabase_client = create_client(
        settings.supabase_url,
        settings.supabase_service_key,
    )
    discovery = AutoDiscovery(settings, supabase_client)

    try:
        # Run queue consumer and auto-discovery in parallel
        await asyncio.gather(
            consumer.start(),
            discovery.run_periodic(interval_hours=6),
        )
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        await consumer.stop()


if __name__ == "__main__":
    asyncio.run(main())
