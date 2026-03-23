"""Queue consumer that polls Supabase for pending analysis jobs."""

import asyncio
import logging

from config import settings

logger = logging.getLogger(__name__)


class QueueConsumer:
    """Polls the analysis_queue table and dispatches jobs to the pipeline."""

    def __init__(self) -> None:
        self._running = False

    async def start(self) -> None:
        """Start the polling loop."""
        self._running = True
        logger.info("Queue consumer started. Polling every %ds", settings.poll_interval_seconds)

        while self._running:
            try:
                await self._poll()
            except Exception:
                logger.exception("Error during queue poll")
            await asyncio.sleep(settings.poll_interval_seconds)

    async def stop(self) -> None:
        """Stop the polling loop."""
        self._running = False
        logger.info("Queue consumer stopped.")

    async def _poll(self) -> None:
        """Check for pending jobs and process them."""
        # TODO: Implement Supabase query for pending analysis jobs
        # TODO: Dispatch to pipeline orchestrator
        pass
