"""FastAPI routes for direct video analysis and health checks."""

import hmac
import logging
import os
import re
import uuid
from typing import Any

from fastapi import FastAPI, HTTPException, Header, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)


class AnalyzeRequest(BaseModel):
    video_id: str = Field(pattern=r'^[a-zA-Z0-9_-]{11}$', max_length=11)


class AnalysisResponse(BaseModel):
    video_id: str
    age_min_appropriate: int = 0
    age_max_appropriate: int = 18
    overstimulation_score: float = 0
    educational_score: float = 0
    scariness_score: float = 0
    brainrot_score: float = 0
    language_safety_score: float = 10
    violence_score: float = 0
    audio_safety_score: float = 0
    content_labels: list[str] = []
    detected_issues: list[str] = []
    analysis_reasoning: str = ""
    confidence: float = 0
    tiers_completed: list[int] = []
    is_globally_blacklisted: bool = False


def create_api(settings: Any, orchestrator: Any, supabase_client: Any) -> FastAPI:
    """Create the FastAPI app with analysis routes."""
    env = os.getenv("ENVIRONMENT", "production")
    if env == "production":
        app = FastAPI(
            title="Baby Monitor Worker API",
            version="1.0.0",
            docs_url=None,
            redoc_url=None,
            openapi_url=None,
        )
    else:
        app = FastAPI(title="Baby Monitor Worker API", version="1.0.0")

    # Rate limiting: max 10 requests/minute per user
    from api.rate_limiter import RateLimiter
    app.add_middleware(RateLimiter, max_requests=10, window_seconds=60)

    # CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[],
        allow_methods=["GET", "POST"],
        allow_headers=["Authorization"],
    )

    api_key = settings.worker_api_key
    if not api_key:
        raise RuntimeError("WORKER_API_KEY environment variable is required")

    def _verify_key(authorization: str | None = Header(None)) -> None:
        if not authorization or not hmac.compare_digest(authorization, f"Bearer {api_key}"):
            raise HTTPException(status_code=401, detail="Invalid API key")

    @app.get("/api/health")
    async def health():
        return {"status": "ok"}

    @app.post("/api/analyze", response_model=AnalysisResponse)
    async def analyze(request: AnalyzeRequest, authorization: str | None = Header(None)):
        _verify_key(authorization)

        video_id = request.video_id
        logger.info("API: Analyzing video %s", video_id)

        try:
            result = await orchestrator.analyze(video_id)
        except Exception as e:
            logger.error("API: Analysis failed for %s: %s", video_id, e)
            raise HTTPException(status_code=500, detail="Analysis failed due to an internal error")

        if result is None:
            raise HTTPException(status_code=404, detail="Analysis failed")

        return AnalysisResponse(
            video_id=video_id,
            age_min_appropriate=result.get("age_min_appropriate", 0),
            age_max_appropriate=result.get("age_max_appropriate", 18),
            overstimulation_score=result.get("overstimulation_score", 0),
            educational_score=result.get("educational_score", 0),
            scariness_score=result.get("scariness_score", 0),
            brainrot_score=result.get("brainrot_score", 0),
            language_safety_score=result.get("language_safety_score", 10),
            violence_score=result.get("violence_score", 0),
            audio_safety_score=result.get("audio_safety_score", 10),
            content_labels=result.get("content_labels", []),
            detected_issues=result.get("detected_issues", []),
            analysis_reasoning=result.get("analysis_reasoning", ""),
            confidence=result.get("confidence", 0),
            tiers_completed=result.get("tiers_completed", []),
            is_globally_blacklisted=result.get("is_globally_blacklisted", False),
        )

    @app.get("/api/analysis/{video_id}", response_model=AnalysisResponse)
    async def get_analysis(video_id: str, authorization: str | None = Header(None)):
        _verify_key(authorization)

        if not re.fullmatch(r'[a-zA-Z0-9_-]{11}', video_id):
            raise HTTPException(status_code=400, detail="Invalid video_id format")

        result = (
            supabase_client.table("video_analyses")
            .select("*")
            .eq("video_id", video_id)
            .maybe_single()
            .execute()
        )

        if not result.data:
            raise HTTPException(status_code=404, detail="Analysis not found")

        data = result.data
        return AnalysisResponse(
            video_id=video_id,
            age_min_appropriate=data.get("age_min_appropriate", 0),
            age_max_appropriate=data.get("age_max_appropriate", 18),
            overstimulation_score=data.get("overstimulation_score", 0),
            educational_score=data.get("educational_score", 0),
            scariness_score=data.get("scariness_score", 0),
            brainrot_score=data.get("brainrot_score", 0),
            language_safety_score=data.get("language_safety_score", 10),
            violence_score=data.get("violence_score", 0),
            audio_safety_score=data.get("audio_safety_score", 10),
            content_labels=data.get("content_labels", []),
            detected_issues=data.get("detected_issues", []),
            analysis_reasoning=data.get("analysis_reasoning", ""),
            confidence=data.get("confidence", 0),
            tiers_completed=data.get("tiers_completed", []),
            is_globally_blacklisted=data.get("is_globally_blacklisted", False),
        )

    @app.get("/api/recommendations/{child_id}")
    async def get_recommendations(
        child_id: str,
        limit: int = Query(default=20, ge=1, le=100),
        authorization: str | None = Header(None),
    ):
        _verify_key(authorization)

        # Validate child_id as UUID
        try:
            uuid.UUID(child_id)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid child_id format")

        from discovery.recommendation_engine import RecommendationEngine

        engine = RecommendationEngine()
        recommendations = engine.get_recommendations(child_id=child_id, limit=limit)
        return {"child_id": child_id, "recommendations": recommendations}

    return app
