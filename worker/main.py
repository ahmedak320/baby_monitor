"""Baby Monitor AI Analysis Worker

Main entry point for the video analysis pipeline.
Polls the Supabase analysis_queue and processes videos through
a 4-tier analysis funnel.
"""

import asyncio
import logging
import sys

from config import settings
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
    logger.info(f"Supabase URL: {settings.supabase_url}")

    consumer = QueueConsumer()
    await consumer.start()


if __name__ == "__main__":
    asyncio.run(main())
