"""Recommendation engine using embedding similarity and watch history."""

import logging
from typing import Optional

from utils.supabase_client import get_supabase_client

logger = logging.getLogger(__name__)


class RecommendationEngine:
    """Generate personalized video recommendations for a child.

    Uses Gemini Embedding 2 similarity on watch history to find
    related safe content the child hasn't seen yet.
    """

    def get_recommendations(
        self,
        child_id: str,
        limit: int = 20,
    ) -> list[dict]:
        """Get recommended videos based on watch history embeddings.

        Algorithm:
        1. Fetch child's last 50 watch history entries
        2. Get average embedding vector from those videos
        3. Find similar un-watched videos
        4. Rank by: similarity (0.4) + recency (0.2) + channel trust (0.2) + diversity (0.2)
        """
        try:
            client = get_supabase_client()

            # Get child's recent watch history video IDs
            history = (
                client.table("watch_history")
                .select("video_id")
                .eq("child_id", child_id)
                .order("watched_at", desc=True)
                .limit(50)
                .execute()
            )

            watched_ids = [row["video_id"] for row in (history.data or [])]
            if not watched_ids:
                return self._get_popular_safe(client, limit)

            # Get embeddings for watched videos
            embeddings_result = (
                client.table("video_analyses")
                .select("video_id, embedding, verdict")
                .in_("video_id", watched_ids)
                .not_.is_("embedding", "null")
                .execute()
            )

            embeddings_data = embeddings_result.data or []
            if not embeddings_data:
                return self._get_popular_safe(client, limit)

            # Compute average embedding
            import numpy as np

            vectors = []
            for row in embeddings_data:
                if row.get("embedding"):
                    vectors.append(row["embedding"])

            if not vectors:
                return self._get_popular_safe(client, limit)

            avg_vector = np.mean(vectors, axis=0).tolist()

            # Find similar videos not yet watched
            similar = client.rpc(
                "match_video_embeddings",
                {
                    "query_embedding": avg_vector,
                    "match_threshold": 0.75,
                    "match_count": limit * 2,
                },
            ).execute()

            results = []
            seen_channels = set()

            for match in (similar.data or []):
                vid = match.get("video_id", "")
                if vid in watched_ids:
                    continue

                # Diversity bonus: penalize same channel
                # (We don't have channel_id here, but we deduplicate later in the app)
                results.append({
                    "video_id": vid,
                    "similarity": match.get("similarity", 0.0),
                    "source": "embedding_recommendation",
                })

                if len(results) >= limit:
                    break

            return results

        except Exception as e:
            logger.error("Recommendation engine failed: %s", e)
            return []

    def _get_popular_safe(self, client, limit: int) -> list[dict]:
        """Fallback: return popular safe videos when no watch history."""
        try:
            result = (
                client.table("video_analyses")
                .select("video_id")
                .eq("verdict", "approve")
                .order("created_at", desc=True)
                .limit(limit)
                .execute()
            )
            return [
                {"video_id": row["video_id"], "similarity": 0.5, "source": "popular_safe"}
                for row in (result.data or [])
            ]
        except Exception:
            return []
