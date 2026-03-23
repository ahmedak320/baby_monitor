"""Pydantic models for video metadata."""

from pydantic import BaseModel


class VideoMetadata(BaseModel):
    """YouTube video metadata."""

    video_id: str
    title: str
    description: str = ""
    channel_id: str = ""
    channel_title: str = ""
    thumbnail_url: str = ""
    duration_seconds: int = 0
    tags: list[str] = []
    category_id: int = 0
    has_captions: bool = False
    view_count: int = 0
    like_count: int = 0
    is_kids_content: bool = False


class TranscriptEntry(BaseModel):
    """A single transcript entry with timing."""

    text: str
    start: float
    duration: float


class VideoTranscript(BaseModel):
    """Full video transcript."""

    video_id: str
    entries: list[TranscriptEntry] = []
    language: str = "en"

    @property
    def full_text(self) -> str:
        return " ".join(e.text for e in self.entries)
