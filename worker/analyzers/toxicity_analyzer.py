"""Text toxicity and hate speech detection using Detoxify and HateSonar."""

import logging
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)

# Lazy-load heavy ML models
_detoxify_model = None
_hatesonar_model = None


def _get_detoxify():
    global _detoxify_model
    if _detoxify_model is None:
        from detoxify import Detoxify
        logger.info("Loading Detoxify model...")
        _detoxify_model = Detoxify("original")
        logger.info("Detoxify model loaded.")
    return _detoxify_model


def _get_hatesonar():
    global _hatesonar_model
    if _hatesonar_model is None:
        from hatesonar import Sonar
        logger.info("Loading HateSonar model...")
        _hatesonar_model = Sonar()
        logger.info("HateSonar model loaded.")
    return _hatesonar_model


@dataclass
class ToxicityResult:
    """Result of toxicity analysis on text."""

    # Detoxify scores (0-1, higher = more toxic)
    toxicity: float = 0.0
    severe_toxicity: float = 0.0
    obscene: float = 0.0
    threat: float = 0.0
    insult: float = 0.0
    identity_hate: float = 0.0

    # HateSonar classification
    hate_speech_score: float = 0.0
    offensive_language_score: float = 0.0

    # Aggregate
    is_safe: bool = True
    max_toxicity_score: float = 0.0
    concerns: list[str] = field(default_factory=list)

    @property
    def safety_score_1_10(self) -> float:
        """Convert to 1-10 scale where 10 = perfectly safe."""
        return max(1.0, 10.0 - (self.max_toxicity_score * 10.0))


class ToxicityAnalyzer:
    """Analyze text for toxicity, hate speech, and offensive language."""

    # Thresholds for flagging content
    TOXICITY_THRESHOLD = 0.5
    SEVERE_THRESHOLD = 0.3
    HATE_SPEECH_THRESHOLD = 0.5

    def analyze(self, text: str) -> ToxicityResult:
        """Run full toxicity analysis on text.

        Combines Detoxify (6-category toxicity) with HateSonar (hate speech detection).
        """
        if not text or len(text.strip()) < 10:
            return ToxicityResult(is_safe=True)

        result = ToxicityResult()
        concerns = []

        # Detoxify analysis
        try:
            detoxify = _get_detoxify()
            scores = detoxify.predict(text)

            result.toxicity = scores["toxicity"]
            result.severe_toxicity = scores["severe_toxicity"]
            result.obscene = scores["obscene"]
            result.threat = scores["threat"]
            result.insult = scores["insult"]
            result.identity_hate = scores["identity_hate"]

            if result.toxicity > self.TOXICITY_THRESHOLD:
                concerns.append(f"toxicity={result.toxicity:.2f}")
            if result.severe_toxicity > self.SEVERE_THRESHOLD:
                concerns.append(f"severe_toxicity={result.severe_toxicity:.2f}")
            if result.obscene > self.TOXICITY_THRESHOLD:
                concerns.append(f"obscene={result.obscene:.2f}")
            if result.threat > self.SEVERE_THRESHOLD:
                concerns.append(f"threat={result.threat:.2f}")
            if result.insult > self.TOXICITY_THRESHOLD:
                concerns.append(f"insult={result.insult:.2f}")
            if result.identity_hate > self.SEVERE_THRESHOLD:
                concerns.append(f"identity_hate={result.identity_hate:.2f}")

        except Exception as e:
            logger.error("Detoxify analysis failed: %s", e)

        # HateSonar analysis
        try:
            sonar = _get_hatesonar()
            hs_result = sonar.ping(text=text)

            for cls in hs_result.get("classes", []):
                if cls["class_name"] == "hate_speech":
                    result.hate_speech_score = cls["confidence"]
                elif cls["class_name"] == "offensive_language":
                    result.offensive_language_score = cls["confidence"]

            if result.hate_speech_score > self.HATE_SPEECH_THRESHOLD:
                concerns.append(f"hate_speech={result.hate_speech_score:.2f}")
            if result.offensive_language_score > self.TOXICITY_THRESHOLD:
                concerns.append(
                    f"offensive_lang={result.offensive_language_score:.2f}"
                )

        except Exception as e:
            logger.error("HateSonar analysis failed: %s", e)

        # Compute aggregate
        all_scores = [
            result.toxicity,
            result.severe_toxicity,
            result.obscene,
            result.threat,
            result.insult,
            result.identity_hate,
            result.hate_speech_score,
            result.offensive_language_score,
        ]
        result.max_toxicity_score = max(all_scores) if all_scores else 0.0
        result.is_safe = len(concerns) == 0
        result.concerns = concerns

        if concerns:
            logger.info("Toxicity concerns found: %s", ", ".join(concerns))

        return result

    def analyze_chunks(self, text: str, chunk_size: int = 5000) -> ToxicityResult:
        """Analyze long text by splitting into chunks and taking worst scores.

        Useful for full video transcripts.
        """
        if len(text) <= chunk_size:
            return self.analyze(text)

        chunks = [text[i : i + chunk_size] for i in range(0, len(text), chunk_size)]
        worst = ToxicityResult()

        for chunk in chunks:
            result = self.analyze(chunk)
            worst.toxicity = max(worst.toxicity, result.toxicity)
            worst.severe_toxicity = max(worst.severe_toxicity, result.severe_toxicity)
            worst.obscene = max(worst.obscene, result.obscene)
            worst.threat = max(worst.threat, result.threat)
            worst.insult = max(worst.insult, result.insult)
            worst.identity_hate = max(worst.identity_hate, result.identity_hate)
            worst.hate_speech_score = max(
                worst.hate_speech_score, result.hate_speech_score
            )
            worst.offensive_language_score = max(
                worst.offensive_language_score, result.offensive_language_score
            )
            worst.concerns.extend(result.concerns)

        # Deduplicate concerns
        worst.concerns = list(set(worst.concerns))
        all_scores = [
            worst.toxicity, worst.severe_toxicity, worst.obscene,
            worst.threat, worst.insult, worst.identity_hate,
            worst.hate_speech_score, worst.offensive_language_score,
        ]
        worst.max_toxicity_score = max(all_scores)
        worst.is_safe = len(worst.concerns) == 0

        return worst
