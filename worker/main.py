"""Baby Monitor AI Analysis Worker

Main entry point for the video analysis pipeline.
Polls the Supabase analysis_queue and processes videos through
a 4-tier analysis funnel.
"""

import asyncio
import logging
import os
import sys

import uvicorn
from supabase import create_client

from api.routes import create_api
from config import settings
from discovery.auto_discovery import AutoDiscovery
from pipeline.orchestrator import PipelineOrchestrator
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
    masked_url = settings.supabase_url[:20] + "***" if len(settings.supabase_url) > 20 else "***"
    logger.info("Supabase URL: %s", masked_url)
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

    # Set up Supabase client
    supabase_client = create_client(
        settings.supabase_url,
        settings.supabase_service_key,
    )

    # Set up auto-discovery
    discovery = AutoDiscovery(settings, supabase_client)

    # Set up FastAPI server
    orchestrator = PipelineOrchestrator(settings, supabase_client)
    app = create_api(settings, orchestrator, supabase_client)

    async def run_api():
        config = uvicorn.Config(
            app, host=os.getenv("API_HOST", "127.0.0.1"), port=settings.api_port, log_level="info"
        )
        server = uvicorn.Server(config)
        await server.serve()

    try:
        # Run queue consumer, auto-discovery, and API in parallel
        await asyncio.gather(
            consumer.start(),
            discovery.run_periodic(interval_hours=6),
            run_api(),
        )
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        await consumer.stop()


if __name__ == "__main__":
    asyncio.run(main())
