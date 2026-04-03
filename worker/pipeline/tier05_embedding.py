"""Tier 0.5: Gemini Embedding 2 pre-filter.

Computes video embeddings and compares against known-safe/unsafe vectors
using cosine similarity. Cheaper than Tier 1 text analysis (~10x).
"""

import logging
import os

from models.video_metadata import VideoMetadata
from utils.provider_rate_limiter import get_rate_limiter
from utils.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)

# Similarity thresholds
SAFE_SIMILARITY_THRESHOLD = 0.92
UNSAFE_SIMILARITY_THRESHOLD = 0.92
FAST_TRACK_CONFIDENCE = 0.88


class Tier05Embedding:
    """Embedding-based pre-filter using Gemini Embedding 2."""

    def __init__(self):
        self._client = None
        self._model = "models/gemini-embedding-001"
        self._rate_limiter = get_rate_limiter("gemini_embedding")
        try:
            from google import genai

            api_key = os.getenv("GEMINI_API_KEY", "")
            if api_key:
                self._client = genai.Client(api_key=api_key)
            else:
                logger.warning("No GEMINI_API_KEY; Tier 0.5 disabled")
        except ImportError:
            logger.warning("google-genai not installed; Tier 0.5 disabled")

    @property
    def is_available(self) -> bool:
        return self._client is not None

    def compute_embedding(self, metadata: VideoMetadata) -> list[float] | None:
        """Compute embedding vector for a video's text content."""
        if not self.is_available:
            return None

        # Combine title + description + first part of transcript
        text = f"{metadata.title}\n{metadata.channel_title}\n{metadata.description[:2000]}"

        try:
            from google.genai import types

            self._rate_limiter.acquire()
            result = self._client.models.embed_content(
                model=self._model,
                contents=text,
                config=types.EmbedContentConfig(
                    task_type="SEMANTIC_SIMILARITY",
                    output_dimensionality=768,
                ),
            )
            return result.embeddings[0].values
        except Exception as e:
            logger.error("Embedding computation failed: %s", e)
            return None

    def find_similar(
        self, embedding: list[float], limit: int = 5
    ) -> list[dict]:
        """Find similar videos by cosine similarity against stored embeddings."""
        try:
            client = get_supabase_client()

            # Clamp limit to prevent excessive RPC results
            clamped_limit = max(1, min(limit, 100))

            # Use Supabase's pgvector similarity search
            # This requires the embedding column and ivfflat index
            result = client.rpc(
                "match_video_embeddings",
                {
                    "query_embedding": embedding,
                    "match_threshold": 0.85,
                    "match_count": clamped_limit,
                },
            ).execute()

            return result.data or []
        except Exception as e:
            logger.warning("Embedding similarity search failed: %s", e)
            return []

    def fast_track(
        self, metadata: VideoMetadata
    ) -> dict | None:
        """Try to fast-track a video based on embedding similarity.

        Returns:
            dict with 'verdict' and 'confidence' if fast-tracked,
            None if the video should proceed to Tier 1.
        """
        if not self.is_available:
            return None

        embedding = self.compute_embedding(metadata)
        if embedding is None:
            return None

        result = None
        similar = self.find_similar(embedding, limit=3)

        if similar:
            best_match = similar[0]
            similarity = best_match.get("similarity", 0.0)
            matched_verdict = best_match.get("verdict", "")

            if similarity >= SAFE_SIMILARITY_THRESHOLD and matched_verdict == "approve":
                logger.info(
                    "Tier 0.5: fast-track SAFE (similarity=%.3f to %s)",
                    similarity,
                    best_match.get("video_id", "?"),
                )
                result = {"verdict": "approve", "confidence": FAST_TRACK_CONFIDENCE}

            elif similarity >= UNSAFE_SIMILARITY_THRESHOLD and matched_verdict == "reject":
                logger.info(
                    "Tier 0.5: fast-track REJECT (similarity=%.3f to %s)",
                    similarity,
                    best_match.get("video_id", "?"),
                )
                result = {"verdict": "reject", "confidence": FAST_TRACK_CONFIDENCE}

        # Always store the embedding for future comparisons
        self._store_embedding(metadata.video_id, embedding)
        return result

    def _store_embedding(self, video_id: str, embedding: list[float]) -> None:
        """Store the computed embedding for future similarity comparisons."""
        try:
            client = get_supabase_client()
            client.table("video_analyses").update(
                {"embedding": embedding}
            ).eq("video_id", video_id).execute()
        except Exception as e:
            logger.warning("Failed to store embedding for %s: %s", video_id, e)
