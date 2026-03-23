"""Extract video captions/transcripts using youtube-transcript-api."""

import logging
from typing import Optional

from youtube_transcript_api import YouTubeTranscriptApi
from youtube_transcript_api._errors import (
    NoTranscriptFound,
    TranscriptsDisabled,
    VideoUnavailable,
)

from models.video_metadata import TranscriptEntry, VideoTranscript

logger = logging.getLogger(__name__)


class CaptionExtractor:
    """Extract video transcripts from YouTube."""

    def extract(self, video_id: str, preferred_lang: str = "en") -> Optional[VideoTranscript]:
        """Extract transcript for a video.

        Tries preferred language first, then falls back to auto-generated,
        then any available language.

        Returns None if no transcript is available.
        """
        try:
            transcript_list = YouTubeTranscriptApi.list_transcripts(video_id)
        except (TranscriptsDisabled, VideoUnavailable) as e:
            logger.warning("No transcripts for %s: %s", video_id, e)
            return None
        except Exception as e:
            logger.error("Error listing transcripts for %s: %s", video_id, e)
            return None

        # Try manual transcript in preferred language
        try:
            transcript = transcript_list.find_manually_created_transcript(
                [preferred_lang]
            )
            return self._parse_transcript(video_id, transcript.fetch(), preferred_lang)
        except NoTranscriptFound:
            pass

        # Try auto-generated in preferred language
        try:
            transcript = transcript_list.find_generated_transcript(
                [preferred_lang]
            )
            return self._parse_transcript(video_id, transcript.fetch(), preferred_lang)
        except NoTranscriptFound:
            pass

        # Try any available transcript and translate
        try:
            for transcript in transcript_list:
                try:
                    if transcript.is_translatable:
                        translated = transcript.translate(preferred_lang)
                        return self._parse_transcript(
                            video_id, translated.fetch(), preferred_lang
                        )
                    else:
                        return self._parse_transcript(
                            video_id, transcript.fetch(), transcript.language_code
                        )
                except Exception:
                    continue
        except Exception:
            pass

        logger.info("No usable transcript found for %s", video_id)
        return None

    def extract_text_only(self, video_id: str) -> Optional[str]:
        """Extract just the full text of the transcript."""
        transcript = self.extract(video_id)
        if transcript is None:
            return None
        return transcript.full_text

    def _parse_transcript(
        self,
        video_id: str,
        raw_entries: list[dict],
        language: str,
    ) -> VideoTranscript:
        entries = [
            TranscriptEntry(
                text=entry["text"],
                start=entry["start"],
                duration=entry["duration"],
            )
            for entry in raw_entries
        ]

        logger.info(
            "Extracted %d transcript entries for %s (%s)",
            len(entries),
            video_id,
            language,
        )

        return VideoTranscript(
            video_id=video_id,
            entries=entries,
            language=language,
        )
