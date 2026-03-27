"""Extract audio from video files using ffmpeg."""

import logging
import os
import subprocess
import tempfile

from config import settings

logger = logging.getLogger(__name__)


class AudioExtractor:
    """Extract audio track from video files."""

    def __init__(self, temp_base: str = ""):
        self._temp_base = temp_base or settings.temp_dir

    def extract_from_video(
        self,
        video_id: str,
        video_path: str | None = None,
    ) -> str | None:
        """Extract audio as WAV from a video file or download first.

        Returns path to WAV file or None if extraction fails.
        Caller must clean up the file.
        """
        import re
        if not re.fullmatch(r'[a-zA-Z0-9_-]{11}', video_id):
            logger.error("Invalid video_id format: %s", video_id[:20])
            return None

        # If no video path, download audio directly via yt-dlp
        if video_path is None:
            return self._download_audio(video_id)

        return self._extract_audio_from_file(video_path, video_id)

    def _download_audio(self, video_id: str) -> str | None:
        """Download audio only via yt-dlp."""
        import yt_dlp

        output_path = os.path.join(
            tempfile.mkdtemp(prefix=f"bm_audio_{video_id}_", dir=self._temp_base),
            "audio.wav",
        )

        ydl_opts = {
            "format": "worstaudio/worst",
            "outtmpl": output_path.replace(".wav", ".%(ext)s"),
            "postprocessors": [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "wav",
                    "preferredquality": "0",
                }
            ],
            "quiet": True,
            "no_warnings": True,
        }

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([f"https://www.youtube.com/watch?v={video_id}"])

            if os.path.exists(output_path):
                logger.info("Audio downloaded for %s: %s", video_id, output_path)
                return output_path

            # Try with different extension
            base = output_path.replace(".wav", "")
            for ext in [".wav", ".webm", ".m4a", ".mp3"]:
                candidate = base + ext
                if os.path.exists(candidate):
                    # Convert to WAV
                    wav_path = base + "_converted.wav"
                    self._convert_to_wav(candidate, wav_path)
                    os.remove(candidate)
                    return wav_path

            return None

        except Exception as e:
            logger.error("Audio download failed for %s: %s", video_id, e)
            return None

    def _extract_audio_from_file(self, video_path: str, video_id: str) -> str | None:
        """Extract audio from an existing video file."""
        output_path = os.path.join(
            os.path.dirname(video_path),
            f"audio_{video_id}.wav",
        )

        try:
            self._convert_to_wav(video_path, output_path)
            return output_path
        except Exception as e:
            logger.error("Audio extraction failed: %s", e)
            return None

    def _convert_to_wav(self, input_path: str, output_path: str):
        """Convert audio/video to 16kHz mono WAV using ffmpeg."""
        cmd = [
            "ffmpeg",
            "-i", input_path,
            "-ar", "16000",
            "-ac", "1",
            "-f", "wav",
            "-y",
            output_path,
        ]
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=120
        )
        if result.returncode != 0:
            raise RuntimeError(f"ffmpeg failed: {result.stderr[:500]}")
