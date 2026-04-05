"""NSFW image classification using NudeNet (ONNX-based)."""

import logging
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)

# NudeNet labels considered unsafe for children
UNSAFE_LABELS = {
    "FEMALE_BREAST_EXPOSED",
    "FEMALE_GENITALIA_EXPOSED",
    "MALE_GENITALIA_EXPOSED",
    "BUTTOCKS_EXPOSED",
    "ANUS_EXPOSED",
}

CONCERNING_LABELS = {
    "FEMALE_BREAST_COVERED",
    "MALE_BREAST_EXPOSED",
    "BELLY_EXPOSED",
    "BUTTOCKS_COVERED",
}

# Lazy-loaded singleton
_detector = None


def _get_detector():
    """Lazy-load the NudeNet detector."""
    global _detector
    if _detector is not None:
        return _detector
    try:
        from nudenet import NudeDetector
        _detector = NudeDetector()
        logger.info("NudeNet NSFW classifier loaded")
        return _detector
    except ImportError:
        logger.warning("nudenet not installed; NSFW classifier disabled")
        return None
    except Exception as e:
        logger.error("Failed to load NudeNet: %s", e)
        return None


@dataclass
class NSFWResult:
    """NSFW classification result for a single frame."""

    frame_path: str
    timestamp: float
    detections: list[dict] = field(default_factory=list)
    # Scores derived from detections
    drawings: float = 0.0
    hentai: float = 0.0
    neutral: float = 1.0
    porn: float = 0.0
    sexy: float = 0.0

    @property
    def is_nsfw(self) -> bool:
        """Whether this frame has explicit NSFW content."""
        return self.porn > 0.5 or self.hentai > 0.5

    @property
    def is_concerning(self) -> bool:
        """Whether this frame has concerning content."""
        return self.sexy > 0.5 or self.is_nsfw

    @property
    def safety_score(self) -> float:
        """0-1 where 1 is completely safe."""
        return max(0.0, 1.0 - max(self.porn, self.hentai, self.sexy * 0.5))


class NSFWClassifier:
    """Classify frames for NSFW content using NudeNet."""

    def classify_frame(self, frame_path: str, timestamp: float = 0.0) -> NSFWResult:
        """Classify a single frame."""
        detector = _get_detector()

        if detector is None:
            return NSFWResult(frame_path=frame_path, timestamp=timestamp)

        try:
            detections = detector.detect(frame_path)

            unsafe_score = 0.0
            concerning_score = 0.0

            for det in detections:
                label = det.get("class", "")
                conf = det.get("score", 0.0)

                if label in UNSAFE_LABELS:
                    unsafe_score = max(unsafe_score, conf)
                elif label in CONCERNING_LABELS:
                    concerning_score = max(concerning_score, conf)

            return NSFWResult(
                frame_path=frame_path,
                timestamp=timestamp,
                detections=detections,
                porn=unsafe_score,
                sexy=concerning_score,
                neutral=max(0.0, 1.0 - unsafe_score - concerning_score),
            )

        except Exception as e:
            logger.error("NSFW classification failed for %s: %s", frame_path, e)
            return NSFWResult(frame_path=frame_path, timestamp=timestamp)

    def classify_frames(
        self,
        frame_paths: list[str],
        timestamps: list[float],
    ) -> list[NSFWResult]:
        """Classify multiple frames."""
        results = []
        for path, ts in zip(frame_paths, timestamps):
            results.append(self.classify_frame(path, ts))
        return results

    def has_nsfw_content(self, results: list[NSFWResult]) -> bool:
        """Check if any frame was flagged NSFW."""
        return any(r.is_nsfw for r in results)

    def has_concerning_content(self, results: list[NSFWResult]) -> bool:
        """Check if any frame has concerning content."""
        return any(r.is_concerning for r in results)

    def worst_safety_score(self, results: list[NSFWResult]) -> float:
        """Get the worst (lowest) safety score across all frames."""
        if not results:
            return 1.0
        return min(r.safety_score for r in results)
