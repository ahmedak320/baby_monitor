"""FastAPI routes for direct video analysis and health checks."""

import logging
from typing import Any

from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel

logger = logging.getLogger(__name__)


class AnalyzeRequest(BaseModel):
    video_id: str


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
    app = FastAPI(title="Baby Monitor Worker API", version="1.0.0")

    api_key = settings.worker_api_key or ""

    def _verify_key(authorization: str | None = Header(None)) -> None:
        if api_key and authorization != f"Bearer {api_key}":
            raise HTTPException(status_code=401, detail="Invalid API key")

    @app.get("/api/health")
    async def health():
        return {"status": "ok", "worker": "baby-monitor-analysis"}

    @app.post("/api/analyze", response_model=AnalysisResponse)
    async def analyze(request: AnalyzeRequest, authorization: str | None = Header(None)):
        _verify_key(authorization)

        video_id = request.video_id
        logger.info(f"API: Analyzing video {video_id}")

        try:
            result = await orchestrator.analyze(video_id)
        except Exception as e:
            logger.error(f"API: Analysis failed for {video_id}: {e}")
            raise HTTPException(status_code=500, detail=str(e))

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

    return app
