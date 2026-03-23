"""NSFW image classification using nsfw_model (TensorFlow Lite)."""

import logging
from dataclasses import dataclass

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

_model = None
_interpreter = None


def _get_model():
    """Lazy-load the NSFW TFLite model."""
    global _model, _interpreter
    if _interpreter is not None:
        return _interpreter

    try:
        import tensorflow as tf

        # Try to load TFLite model
        # In production, download the nsfw_model TFLite file
        # For now, use a placeholder that flags nothing
        logger.warning(
            "NSFW model not found. Using placeholder classifier. "
            "Download nsfw_mobilenet_v2.tflite for production use."
        )
        return None
    except ImportError:
        logger.warning("TensorFlow not available. NSFW classifier disabled.")
        return None


@dataclass
class NSFWResult:
    """NSFW classification result for a single frame."""

    frame_path: str
    timestamp: float
    drawings: float = 0.0
    hentai: float = 0.0
    neutral: float = 1.0
    porn: float = 0.0
    sexy: float = 0.0

    @property
    def is_nsfw(self) -> bool:
        """Whether this frame is NSFW (porn or hentai above threshold)."""
        return self.porn > 0.5 or self.hentai > 0.5

    @property
    def is_concerning(self) -> bool:
        """Whether this frame has concerning content (sexy above threshold)."""
        return self.sexy > 0.5 or self.is_nsfw

    @property
    def safety_score(self) -> float:
        """0-1 where 1 is completely safe."""
        return max(0.0, 1.0 - max(self.porn, self.hentai, self.sexy * 0.5))


class NSFWClassifier:
    """Classify frames for NSFW content."""

    def classify_frame(self, frame_path: str, timestamp: float = 0.0) -> NSFWResult:
        """Classify a single frame."""
        model = _get_model()

        if model is None:
            # Placeholder: assume safe
            return NSFWResult(frame_path=frame_path, timestamp=timestamp)

        try:
            img = Image.open(frame_path).resize((224, 224))
            img_array = np.array(img, dtype=np.float32) / 255.0
            img_array = np.expand_dims(img_array, axis=0)

            # Run inference
            model.set_tensor(model.get_input_details()[0]["index"], img_array)
            model.invoke()
            output = model.get_tensor(model.get_output_details()[0]["index"])[0]

            return NSFWResult(
                frame_path=frame_path,
                timestamp=timestamp,
                drawings=float(output[0]),
                hentai=float(output[1]),
                neutral=float(output[2]),
                porn=float(output[3]),
                sexy=float(output[4]),
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
