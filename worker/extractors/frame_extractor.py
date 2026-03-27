"""Extract video frames using yt-dlp + OpenCV."""

import logging
import os
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

from config import settings

logger = logging.getLogger(__name__)


@dataclass
class ExtractedFrames:
    """Container for extracted video frames."""

    video_id: str
    frame_paths: list[str]
    frame_timestamps: list[float]  # seconds into video
    total_duration: float
    temp_dir: str  # caller must clean up

    @property
    def count(self) -> int:
        return len(self.frame_paths)

    def cleanup(self):
        """Remove temporary files."""
        if os.path.exists(self.temp_dir):
            shutil.rmtree(self.temp_dir)
            logger.debug("Cleaned up temp dir: %s", self.temp_dir)


class FrameExtractor:
    """Download video and extract representative frames.

    Frame sampling strategy (from plan):
    - Short (<5min): every 15s = ~20 frames max
    - Medium (5-20min): every 30s = ~40 frames max
    - Long (20+min): every 45s = ~50 frames max
    - Always includes first and last frame
    - Scene change detection via pixel difference threshold
    """

    def __init__(self, temp_base: str = ""):
        self._temp_base = temp_base or settings.temp_dir

    def extract(
        self,
        video_id: str,
        duration_seconds: int = 0,
        max_frames: int = 50,
    ) -> ExtractedFrames | None:
        """Download video and extract sampled frames.

        Returns ExtractedFrames or None if download/extraction fails.
        Caller must call .cleanup() when done.
        """
        import re
        if not re.fullmatch(r'[a-zA-Z0-9_-]{11}', video_id):
            logger.error("Invalid video_id format: %s", video_id[:20])
            return None

        temp_dir = tempfile.mkdtemp(prefix=f"bm_{video_id}_", dir=self._temp_base)

        try:
            # Download video
            video_path = self._download_video(video_id, temp_dir)
            if not video_path:
                shutil.rmtree(temp_dir)
                return None

            # Extract frames
            frames = self._extract_frames(
                video_path, video_id, temp_dir, duration_seconds, max_frames
            )

            # Delete the video file (keep only frames)
            os.remove(video_path)

            return frames

        except Exception as e:
            logger.error("Frame extraction failed for %s: %s", video_id, e)
            shutil.rmtree(temp_dir, ignore_errors=True)
            return None

    def _download_video(self, video_id: str, temp_dir: str) -> str | None:
        """Download video using yt-dlp."""
        import yt_dlp

        output_template = os.path.join(temp_dir, "video.%(ext)s")

        ydl_opts = {
            "format": "worst[ext=mp4]/worst",  # lowest quality to save bandwidth
            "outtmpl": output_template,
            "quiet": True,
            "no_warnings": True,
            "socket_timeout": 30,
        }

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([f"https://www.youtube.com/watch?v={video_id}"])

            # Find the downloaded file
            for f in Path(temp_dir).iterdir():
                if f.name.startswith("video."):
                    logger.info("Downloaded %s: %s", video_id, f.name)
                    return str(f)

            return None

        except Exception as e:
            logger.error("Download failed for %s: %s", video_id, e)
            return None

    def _extract_frames(
        self,
        video_path: str,
        video_id: str,
        temp_dir: str,
        duration_hint: int,
        max_frames: int,
    ) -> ExtractedFrames:
        """Extract frames from downloaded video."""

        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS) or 30
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        duration = total_frames / fps if fps > 0 else duration_hint

        # Determine sampling interval
        if duration < 300:  # < 5 min
            interval_seconds = 15
        elif duration < 1200:  # < 20 min
            interval_seconds = 30
        else:
            interval_seconds = 45

        interval_frames = int(interval_seconds * fps)

        frame_paths = []
        frame_timestamps = []
        prev_frame = None
        frame_index = 0
        scene_change_threshold = 30.0  # Mean pixel difference for scene change

        while cap.isOpened() and len(frame_paths) < max_frames:
            ret, frame = cap.read()
            if not ret:
                break

            timestamp = frame_index / fps

            should_extract = False

            # First frame
            if frame_index == 0:
                should_extract = True
            # Regular interval sampling
            elif frame_index % interval_frames == 0:
                should_extract = True
            # Scene change detection
            elif prev_frame is not None and frame_index % int(fps) == 0:
                diff = cv2.absdiff(frame, prev_frame)
                mean_diff = np.mean(diff)
                if mean_diff > scene_change_threshold:
                    should_extract = True

            if should_extract:
                frame_path = os.path.join(
                    temp_dir, f"frame_{len(frame_paths):04d}_{timestamp:.1f}s.jpg"
                )
                cv2.imwrite(frame_path, frame)
                frame_paths.append(frame_path)
                frame_timestamps.append(timestamp)

            prev_frame = frame.copy() if frame_index % int(fps) == 0 else prev_frame
            frame_index += 1

        cap.release()

        # Always try to include last frame
        if total_frames > 0 and len(frame_paths) < max_frames:
            cap2 = cv2.VideoCapture(video_path)
            cap2.set(cv2.CAP_PROP_POS_FRAMES, total_frames - 1)
            ret, frame = cap2.read()
            if ret:
                ts = (total_frames - 1) / fps
                path = os.path.join(temp_dir, f"frame_last_{ts:.1f}s.jpg")
                cv2.imwrite(path, frame)
                frame_paths.append(path)
                frame_timestamps.append(ts)
            cap2.release()

        logger.info(
            "Extracted %d frames from %s (%.0fs video, %ds interval)",
            len(frame_paths),
            video_id,
            duration,
            interval_seconds,
        )

        return ExtractedFrames(
            video_id=video_id,
            frame_paths=frame_paths,
            frame_timestamps=frame_timestamps,
            total_duration=duration,
            temp_dir=temp_dir,
        )
