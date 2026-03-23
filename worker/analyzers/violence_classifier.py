"""Violence detection using CLIP-based NSFW detector concepts.

Uses a simple heuristic approach with OpenCV for now.
Can be upgraded to CLIP-based model for production.
"""

import logging
from dataclasses import dataclass

import cv2
import numpy as np

logger = logging.getLogger(__name__)


@dataclass
class ViolenceResult:
    """Violence detection result for a frame."""

    frame_path: str
    timestamp: float
    violence_score: float = 0.0  # 0=safe, 1=violent
    darkness_score: float = 0.0  # 0=bright, 1=very dark
    red_intensity: float = 0.0  # 0=no red, 1=lots of red (blood indicator)
    flash_score: float = 0.0  # 0=stable, 1=bright flash

    @property
    def is_concerning(self) -> bool:
        return self.violence_score > 0.5


class ViolenceClassifier:
    """Detect potential violent or disturbing visual content.

    Uses OpenCV-based heuristics:
    - Darkness analysis (scary/horror content tends to be dark)
    - Red color intensity (blood/gore indicator)
    - Flash detection (seizure-inducing content)
    - Overall visual intensity
    """

    def classify_frame(self, frame_path: str, timestamp: float = 0.0) -> ViolenceResult:
        """Analyze a single frame for violence indicators."""
        try:
            frame = cv2.imread(frame_path)
            if frame is None:
                return ViolenceResult(frame_path=frame_path, timestamp=timestamp)

            # Convert to different color spaces
            hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

            # Darkness analysis
            mean_brightness = np.mean(gray) / 255.0
            darkness_score = max(0.0, 1.0 - mean_brightness * 2)

            # Red intensity (potential blood/gore)
            # Red in HSV: H=0-10 or H=170-180, S>50, V>50
            lower_red1 = np.array([0, 50, 50])
            upper_red1 = np.array([10, 255, 255])
            lower_red2 = np.array([170, 50, 50])
            upper_red2 = np.array([180, 255, 255])
            mask1 = cv2.inRange(hsv, lower_red1, upper_red1)
            mask2 = cv2.inRange(hsv, lower_red2, upper_red2)
            red_ratio = (np.sum(mask1 > 0) + np.sum(mask2 > 0)) / (
                frame.shape[0] * frame.shape[1]
            )
            red_intensity = min(1.0, red_ratio * 5)  # Amplify since blood is localized

            # Flash/brightness spike detection
            flash_score = 0.0
            if mean_brightness > 0.9:
                flash_score = (mean_brightness - 0.9) * 10  # 0.9->0, 1.0->1

            # Composite violence score
            violence_score = (
                darkness_score * 0.3
                + red_intensity * 0.5
                + flash_score * 0.2
            )
            violence_score = min(1.0, violence_score)

            return ViolenceResult(
                frame_path=frame_path,
                timestamp=timestamp,
                violence_score=violence_score,
                darkness_score=darkness_score,
                red_intensity=red_intensity,
                flash_score=flash_score,
            )

        except Exception as e:
            logger.error("Violence classification failed for %s: %s", frame_path, e)
            return ViolenceResult(frame_path=frame_path, timestamp=timestamp)

    def classify_frames(
        self,
        frame_paths: list[str],
        timestamps: list[float],
    ) -> list[ViolenceResult]:
        """Classify multiple frames."""
        return [
            self.classify_frame(path, ts)
            for path, ts in zip(frame_paths, timestamps)
        ]

    def detect_overstimulation(
        self,
        frame_paths: list[str],
        timestamps: list[float],
    ) -> float:
        """Detect overstimulating content via rapid visual changes.

        Returns 0-1 score where 1 = extremely overstimulating.
        """
        if len(frame_paths) < 2:
            return 0.0

        differences = []
        prev_frame = None

        for path in frame_paths:
            frame = cv2.imread(path)
            if frame is None:
                continue

            frame_small = cv2.resize(frame, (64, 64))

            if prev_frame is not None:
                diff = cv2.absdiff(frame_small, prev_frame)
                mean_diff = np.mean(diff) / 255.0
                differences.append(mean_diff)

            prev_frame = frame_small

        if not differences:
            return 0.0

        # High mean difference across frames = overstimulating
        avg_diff = np.mean(differences)
        max_diff = max(differences)

        # Score: combination of average and max change rate
        overstim_score = min(1.0, avg_diff * 5 + max_diff * 3)

        return overstim_score
