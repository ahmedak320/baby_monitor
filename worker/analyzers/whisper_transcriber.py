"""Speech-to-text transcription using faster-whisper."""

import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)

_model = None


def _get_model():
    """Lazy-load Whisper model."""
    global _model
    if _model is not None:
        return _model

    try:
        from faster_whisper import WhisperModel
        logger.info("Loading Whisper model (tiny)...")
        _model = WhisperModel("tiny", device="cpu", compute_type="int8")
        logger.info("Whisper model loaded.")
        return _model
    except ImportError:
        logger.warning("faster-whisper not available. Transcription disabled.")
        return None
    except Exception as e:
        logger.error("Whisper model load failed: %s", e)
        return None


@dataclass
class WhisperResult:
    """Result of Whisper transcription."""

    text: str = ""
    language: str = ""
    duration_seconds: float = 0.0
    has_speech: bool = False
    has_music: bool = False  # Inferred from low speech probability


class WhisperTranscriber:
    """Transcribe audio using faster-whisper for lyrics and speech analysis."""

    def transcribe(self, wav_path: str) -> WhisperResult:
        """Transcribe a WAV audio file.

        Returns transcription text and metadata.
        Useful for analyzing song lyrics and spoken content.
        """
        model = _get_model()
        if model is None:
            return WhisperResult()

        try:
            segments, info = model.transcribe(
                wav_path,
                beam_size=1,  # Fast mode
                vad_filter=True,  # Skip silence
                language=None,  # Auto-detect
            )

            text_parts = []
            total_duration = 0.0

            for segment in segments:
                text_parts.append(segment.text.strip())
                total_duration = max(total_duration, segment.end)

            full_text = " ".join(text_parts)

            result = WhisperResult(
                text=full_text,
                language=info.language or "",
                duration_seconds=total_duration,
                has_speech=len(full_text) > 20,
                has_music=info.language_probability < 0.5 if info.language_probability else False,
            )

            logger.info(
                "Whisper transcription: %d chars, lang=%s, speech=%s",
                len(full_text),
                result.language,
                result.has_speech,
            )

            return result

        except Exception as e:
            logger.error("Whisper transcription failed: %s", e)
            return WhisperResult()
