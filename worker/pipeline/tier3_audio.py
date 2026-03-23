"""Tier 3: Audio analysis.

Cost: ~$0.005/video
Triggered: only when Tier 1 or Tier 2 flags audio concerns
"""

import logging
import os

from analyzers.audio_classifier import AudioClassifier
from analyzers.toxicity_analyzer import ToxicityAnalyzer
from analyzers.whisper_transcriber import WhisperTranscriber
from extractors.audio_extractor import AudioExtractor
from models.analysis_result import AnalysisResult, AnalysisScores, Verdict
from models.video_metadata import VideoMetadata

logger = logging.getLogger(__name__)


class Tier3AudioPipeline:
    """Tier 3: Analyze video audio for safety concerns.

    Pipeline:
    1. Extract audio from video (yt-dlp + ffmpeg)
    2. Run audio classifier (volume spikes, screaming, jump scares)
    3. If speech/lyrics detected: transcribe with Whisper
    4. If lyrics found: run through toxicity analyzer
    5. Merge audio scores with Tier 1+2 scores
    """

    def __init__(self):
        self._audio_extractor = AudioExtractor()
        self._audio_classifier = AudioClassifier()
        self._whisper = WhisperTranscriber()
        self._toxicity = ToxicityAnalyzer()

    def analyze(
        self,
        metadata: VideoMetadata,
        previous_result: AnalysisResult,
    ) -> AnalysisResult:
        """Run Tier 3 audio analysis, building on previous tier results."""

        logger.info("Tier 3 starting for: %s", metadata.video_id)

        # Step 1: Extract audio
        wav_path = self._audio_extractor.extract_from_video(metadata.video_id)
        if wav_path is None:
            logger.warning("Audio extraction failed for %s", metadata.video_id)
            return self._mark_tier_complete(
                previous_result, metadata.video_id, "audio_extraction_failed"
            )

        try:
            # Step 2: Audio classification
            audio_result = self._audio_classifier.analyze(wav_path)

            issues = list(previous_result.detected_issues)
            issues.extend(audio_result.concerns)
            reasoning = previous_result.analysis_reasoning

            # Step 3: Whisper transcription (for lyrics/speech analysis)
            whisper_result = self._whisper.transcribe(wav_path)
            lyrics_toxicity = None

            if whisper_result.has_speech and len(whisper_result.text) > 50:
                # Step 4: Check transcribed lyrics/speech for toxicity
                lyrics_toxicity = self._toxicity.analyze(whisper_result.text)

                if not lyrics_toxicity.is_safe:
                    issues.extend(
                        [f"audio_lyrics_{c}" for c in lyrics_toxicity.concerns]
                    )
                    reasoning += f" | Tier 3: lyrics concerns found"

            # Step 5: Merge results
            result = self._merge_results(
                metadata,
                previous_result,
                audio_result,
                whisper_result,
                lyrics_toxicity,
                issues,
                reasoning,
            )

            logger.info(
                "Tier 3 complete for %s: verdict=%s, audio_safety=%.1f",
                metadata.video_id,
                result.verdict.value,
                result.scores.audio_safety_score,
            )

            return result

        finally:
            # Cleanup audio file
            if wav_path and os.path.exists(wav_path):
                os.remove(wav_path)
                # Remove temp directory too
                parent_dir = os.path.dirname(wav_path)
                if os.path.isdir(parent_dir) and parent_dir.startswith("/tmp"):
                    try:
                        os.rmdir(parent_dir)
                    except OSError:
                        pass

    def _merge_results(
        self,
        metadata: VideoMetadata,
        prev: AnalysisResult,
        audio,
        whisper,
        lyrics_tox,
        issues: list[str],
        reasoning: str,
    ) -> AnalysisResult:
        """Merge audio analysis into previous tier results."""

        # Compute audio safety score
        audio_safety = audio.audio_safety_score
        if lyrics_tox and not lyrics_tox.is_safe:
            audio_safety = min(audio_safety, lyrics_tox.safety_score_1_10)

        scores = AnalysisScores(
            age_min_appropriate=prev.scores.age_min_appropriate,
            age_max_appropriate=prev.scores.age_max_appropriate,
            overstimulation_score=prev.scores.overstimulation_score,
            educational_score=prev.scores.educational_score,
            scariness_score=max(
                prev.scores.scariness_score,
                audio.jump_scare_risk * 10,
            ),
            brainrot_score=prev.scores.brainrot_score,
            language_safety_score=min(
                prev.scores.language_safety_score,
                lyrics_tox.safety_score_1_10 if lyrics_tox else 10.0,
            ),
            violence_score=prev.scores.violence_score,
            ad_commercial_score=prev.scores.ad_commercial_score,
            audio_safety_score=audio_safety,
        )

        # Determine final verdict
        if audio.jump_scare_risk > 0.7 or audio_safety < 3:
            verdict = Verdict.REJECT
        elif prev.verdict == Verdict.REJECT:
            verdict = Verdict.REJECT
        elif prev.verdict == Verdict.APPROVE and audio_safety > 6:
            verdict = Verdict.APPROVE
        else:
            # Use previous verdict — audio didn't change the decision
            verdict = prev.verdict if prev.verdict != Verdict.NEEDS_AUDIO_REVIEW else Verdict.APPROVE

        # Final confidence
        confidence = min(0.95, prev.confidence + 0.10)

        return AnalysisResult(
            video_id=metadata.video_id,
            verdict=verdict,
            scores=scores,
            tiers_completed=prev.tiers_completed + [3],
            content_labels=prev.content_labels,
            detected_issues=issues,
            analysis_reasoning=reasoning,
            confidence=confidence,
        )

    def _mark_tier_complete(
        self,
        prev: AnalysisResult,
        video_id: str,
        issue: str,
    ) -> AnalysisResult:
        """Return previous result with Tier 3 marked as attempted."""
        return AnalysisResult(
            video_id=video_id,
            verdict=prev.verdict,
            scores=prev.scores,
            tiers_completed=prev.tiers_completed + [3],
            content_labels=prev.content_labels,
            detected_issues=prev.detected_issues + [issue],
            analysis_reasoning=prev.analysis_reasoning + f" | Tier 3: {issue}",
            confidence=prev.confidence,
        )
