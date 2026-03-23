"""Queue consumer that polls Supabase for pending analysis jobs."""

import asyncio
import logging
import uuid

from config import settings
from pipeline.orchestrator import PipelineOrchestrator
from pipeline.result_writer import ResultWriter
from utils.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)


class QueueConsumer:
    """Polls the analysis_queue table and dispatches jobs to the pipeline."""

    def __init__(self) -> None:
        self._running = False
        self._worker_id = f"worker-{uuid.uuid4().hex[:8]}"
        self._orchestrator = PipelineOrchestrator()
        self._writer = ResultWriter()
        self._client = get_supabase_client()

    async def start(self) -> None:
        """Start the polling loop."""
        self._running = True
        logger.info(
            "Queue consumer %s started. Polling every %ds",
            self._worker_id,
            settings.poll_interval_seconds,
        )

        while self._running:
            try:
                jobs_processed = await self._poll()
                if jobs_processed == 0:
                    await asyncio.sleep(settings.poll_interval_seconds)
                else:
                    # Process next job immediately if there was work
                    await asyncio.sleep(1)
            except Exception:
                logger.exception("Error during queue poll")
                await asyncio.sleep(settings.poll_interval_seconds)

    async def stop(self) -> None:
        """Stop the polling loop."""
        self._running = False
        logger.info("Queue consumer %s stopped.", self._worker_id)

    async def _poll(self) -> int:
        """Check for pending jobs and process them. Returns count processed."""
        # Claim the highest priority queued job
        job = self._claim_job()
        if job is None:
            return 0

        video_id = job["video_id"]
        job_id = job["id"]

        logger.info("Processing job %s for video %s", job_id, video_id)

        try:
            # Run analysis pipeline (synchronous — runs ML models)
            result = await asyncio.get_event_loop().run_in_executor(
                None, self._orchestrator.analyze, video_id
            )

            # Mark job as completed
            self._complete_job(job_id)
            logger.info("Job %s completed: verdict=%s", job_id, result.verdict.value)
            return 1

        except Exception as e:
            logger.exception("Job %s failed: %s", job_id, e)
            self._fail_job(job_id, str(e))
            self._writer.mark_failed(video_id, str(e))
            return 0

    def _claim_job(self) -> dict | None:
        """Claim the next available job from the queue.

        Uses status update as a lock: only one worker can claim a job.
        """
        try:
            # Find the highest priority queued job
            result = (
                self._client.table("analysis_queue")
                .select("*")
                .eq("status", "queued")
                .lt("attempts", 3)  # Skip jobs that failed too many times
                .order("priority", desc=False)
                .order("created_at", desc=False)
                .limit(1)
                .execute()
            )

            if not result.data:
                return None

            job = result.data[0]

            # Claim it by updating status + worker_id
            self._client.table("analysis_queue").update({
                "status": "processing",
                "worker_id": self._worker_id,
                "started_at": "now()",
                "attempts": job.get("attempts", 0) + 1,
            }).eq("id", job["id"]).eq("status", "queued").execute()

            return job

        except Exception as e:
            logger.error("Failed to claim job: %s", e)
            return None

    def _complete_job(self, job_id: str) -> None:
        """Mark a job as completed."""
        try:
            self._client.table("analysis_queue").update({
                "status": "completed",
                "completed_at": "now()",
            }).eq("id", job_id).execute()
        except Exception as e:
            logger.error("Failed to complete job %s: %s", job_id, e)

    def _fail_job(self, job_id: str, error: str) -> None:
        """Mark a job as failed."""
        try:
            self._client.table("analysis_queue").update({
                "status": "failed",
                "error_message": error[:1000],
            }).eq("id", job_id).execute()
        except Exception as e:
            logger.error("Failed to mark job %s as failed: %s", job_id, e)
