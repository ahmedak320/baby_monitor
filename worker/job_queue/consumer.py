"""Queue consumer that polls Supabase for pending analysis jobs."""

import asyncio
import logging
import uuid
from datetime import UTC, datetime, timedelta

from config import settings
from pipeline.orchestrator import PipelineOrchestrator
from pipeline.result_writer import ResultWriter
from utils.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)

# How long to pause when hitting API rate limits (10 minutes)
RATE_LIMIT_PAUSE_SECONDS = 600


class QueueConsumer:
    """Polls the analysis_queue table and dispatches jobs to the pipeline."""

    def __init__(self) -> None:
        self._running = False
        self._worker_id = f"worker-{uuid.uuid4().hex[:8]}"
        self._orchestrator = PipelineOrchestrator()
        self._writer = ResultWriter()
        self._client = get_supabase_client()
        self._poll_count = 0
        self._reset_interval = 100  # Reset stalled jobs every 100 polls

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
                # Periodically reset stalled jobs
                self._poll_count += 1
                if self._poll_count >= self._reset_interval:
                    self._reset_stalled_jobs()
                    self._poll_count = 0

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
            # Run analysis pipeline with a 1-hour timeout to prevent hung jobs
            result = await asyncio.wait_for(
                asyncio.get_event_loop().run_in_executor(
                    None, self._orchestrator.analyze, video_id
                ),
                timeout=3600,  # 1 hour
            )

            # Mark job as completed
            self._complete_job(job_id)
            logger.info("Job %s completed: verdict=%s", job_id, result.verdict.value)
            return 1

        except asyncio.TimeoutError:
            error_msg = f"Job {job_id} timed out after 1 hour analyzing video {video_id}"
            logger.error(error_msg)
            self._fail_job(job_id, error_msg)
            self._writer.mark_failed(video_id, error_msg)
            return 0

        except Exception as e:
            error_str = str(e)
            is_rate_limit = "429" in error_str or "RESOURCE_EXHAUSTED" in error_str
            is_frame_fail = "Frame extraction failed" in error_str

            if is_rate_limit:
                # Re-queue the job so it can be retried later
                logger.warning(
                    "Job %s hit rate limit — re-queuing and pausing %ds: %s",
                    job_id, RATE_LIMIT_PAUSE_SECONDS, error_str[:200],
                )
                self._requeue_job(job_id)
                await asyncio.sleep(RATE_LIMIT_PAUSE_SECONDS)
                return 0

            if is_frame_fail:
                # Re-queue — frame extraction may succeed on retry
                logger.warning("Job %s frame extraction failed — re-queuing: %s", job_id, error_str[:200])
                self._requeue_job(job_id)
                return 0

            logger.exception("Job %s failed: %s", job_id, e)
            self._fail_job(job_id, error_str)
            self._writer.mark_failed(video_id, error_str)
            return 0

    def _claim_job(self) -> dict | None:
        """Claim the next available job from the queue.

        Uses status update as a lock: only one worker can claim a job.
        """
        try:
            # Find the highest priority queued job
            # Priority: 1=playing now, 2=search, 3=parent, 5=feed, 8=discovery
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
            update_result = (
                self._client.table("analysis_queue")
                .update({
                    "status": "processing",
                    "worker_id": self._worker_id,
                    "started_at": "now()",
                    "attempts": job.get("attempts", 0) + 1,
                })
                .eq("id", job["id"])
                .eq("status", "queued")
                .execute()
            )

            if not update_result.data:
                logger.debug("Job %s already claimed by another worker", job["id"])
                return None

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

    def _requeue_job(self, job_id: str) -> None:
        """Put a job back in the queue for later retry."""
        try:
            self._client.table("analysis_queue").update({
                "status": "queued",
                "worker_id": None,
                "started_at": None,
            }).eq("id", job_id).execute()
        except Exception as e:
            logger.error("Failed to re-queue job %s: %s", job_id, e)

    def _fail_job(self, job_id: str, error: str) -> None:
        """Mark a job as failed."""
        logger.error("Job %s failed with error: %s", job_id, error)
        try:
            self._client.table("analysis_queue").update({
                "status": "failed",
                "error_message": str(error)[:500],
            }).eq("id", job_id).execute()
        except Exception as e:
            logger.error("Failed to mark job %s as failed: %s", job_id, e)

    def _reset_stalled_jobs(self) -> None:
        """Reset jobs stuck in failed state after 24 hours to allow retry."""
        try:
            cutoff = (datetime.now(UTC) - timedelta(hours=24)).isoformat()
            result = (
                self._client.table("analysis_queue")
                .update({
                    "attempts": 0,
                    "status": "queued",
                    "error_message": "Auto-reset after 24 hours",
                })
                .eq("status", "failed")
                .lt("updated_at", cutoff)
                .execute()
            )
            if result.data:
                logger.info("Reset %d stalled failed jobs for retry", len(result.data))
        except Exception as e:
            logger.error("Failed to reset stalled jobs: %s", e)
