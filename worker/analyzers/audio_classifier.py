"""Audio event classification and analysis.

Uses volume analysis and audio feature extraction to detect:
- Screaming, shouting
- Sudden volume spikes (jump scares)
- Music vs speech ratio
- Overall loudness characteristics
"""

import logging
from dataclasses import dataclass, field

import numpy as np

logger = logging.getLogger(__name__)


@dataclass
class AudioAnalysisResult:
    """Result of audio analysis."""

    # Volume analysis
    mean_volume: float = 0.0          # 0-1 average volume
    max_volume: float = 0.0           # 0-1 peak volume
    volume_variance: float = 0.0      # higher = more dynamic
    sudden_spike_count: int = 0       # number of sudden volume jumps

    # Content classification
    has_screaming: bool = False
    has_loud_music: bool = False
    speech_ratio: float = 0.5         # 0-1 estimated speech vs music

    # Safety scores
    jump_scare_risk: float = 0.0      # 0-1
    audio_safety_score: float = 10.0  # 1-10 (10=safest)

    concerns: list[str] = field(default_factory=list)


class AudioClassifier:
    """Classify audio for safety concerns.

    Analyzes WAV files for volume spikes, screaming patterns, and overall
    audio safety characteristics.
    """

    # Volume spike threshold (ratio of local to global RMS)
    SPIKE_THRESHOLD = 4.0
    # Window size for local RMS in samples (at 16kHz)
    WINDOW_SIZE = 16000  # 1 second windows

    def analyze(self, wav_path: str) -> AudioAnalysisResult:
        """Analyze a WAV audio file."""
        try:
            import wave

            with wave.open(wav_path, "rb") as wf:
                n_channels = wf.getnchannels()
                sample_width = wf.getsampwidth()
                framerate = wf.getframerate()
                n_frames = wf.getnframes()
                raw_data = wf.readframes(n_frames)

            # Convert to numpy array
            if sample_width == 2:
                audio = np.frombuffer(raw_data, dtype=np.int16).astype(np.float32)
            elif sample_width == 4:
                audio = np.frombuffer(raw_data, dtype=np.int32).astype(np.float32)
            else:
                audio = np.frombuffer(raw_data, dtype=np.uint8).astype(np.float32) - 128

            if n_channels > 1:
                audio = audio[::n_channels]  # Take first channel

            # Normalize to 0-1
            max_val = max(abs(audio.max()), abs(audio.min()), 1.0)
            audio_norm = audio / max_val

            return self._analyze_signal(audio_norm, framerate)

        except Exception as e:
            logger.error("Audio analysis failed for %s: %s", wav_path, e)
            return AudioAnalysisResult()

    def _analyze_signal(
        self, audio: np.ndarray, sample_rate: int
    ) -> AudioAnalysisResult:
        """Analyze the normalized audio signal."""
        result = AudioAnalysisResult()

        # Basic volume stats
        rms_values = self._compute_rms_windows(audio, self.WINDOW_SIZE)
        if len(rms_values) == 0:
            return result

        result.mean_volume = float(np.mean(rms_values))
        result.max_volume = float(np.max(rms_values))
        result.volume_variance = float(np.var(rms_values))

        # Detect sudden volume spikes (potential jump scares)
        global_rms = np.mean(rms_values) + 1e-6
        spikes = []
        for i, rms in enumerate(rms_values):
            if rms / global_rms > self.SPIKE_THRESHOLD:
                spikes.append(i)

        result.sudden_spike_count = len(spikes)

        # Jump scare risk based on spike count and intensity
        if len(spikes) > 0:
            max_spike_ratio = max(rms_values[s] / global_rms for s in spikes)
            result.jump_scare_risk = min(1.0, len(spikes) * 0.15 + max_spike_ratio * 0.1)
            result.concerns.append(f"volume_spikes_x{len(spikes)}")

        # Screaming detection heuristic
        # High frequency energy + high volume = likely screaming
        high_freq_energy = self._high_frequency_ratio(audio, sample_rate)
        if high_freq_energy > 0.4 and result.max_volume > 0.7:
            result.has_screaming = True
            result.concerns.append("potential_screaming")

        # Loud music detection
        if result.mean_volume > 0.5 and result.volume_variance < 0.02:
            result.has_loud_music = True

        # Compute safety score
        penalty = 0.0
        if result.jump_scare_risk > 0.3:
            penalty += result.jump_scare_risk * 3
        if result.has_screaming:
            penalty += 2.0
        if result.volume_variance > 0.1:
            penalty += 1.0
        if result.sudden_spike_count > 5:
            penalty += 1.0

        result.audio_safety_score = max(1.0, 10.0 - penalty)

        return result

    def _compute_rms_windows(
        self, audio: np.ndarray, window_size: int
    ) -> np.ndarray:
        """Compute RMS energy for each window."""
        n_windows = len(audio) // window_size
        if n_windows == 0:
            return np.array([np.sqrt(np.mean(audio**2))])

        rms_values = np.zeros(n_windows)
        for i in range(n_windows):
            start = i * window_size
            end = start + window_size
            window = audio[start:end]
            rms_values[i] = np.sqrt(np.mean(window**2))

        return rms_values

    def _high_frequency_ratio(
        self, audio: np.ndarray, sample_rate: int
    ) -> float:
        """Ratio of high frequency energy to total energy."""
        try:
            fft = np.fft.rfft(audio[:sample_rate * 5])  # First 5 seconds
            freqs = np.fft.rfftfreq(len(audio[:sample_rate * 5]), 1 / sample_rate)
            magnitudes = np.abs(fft)

            total_energy = np.sum(magnitudes**2) + 1e-6
            high_freq_mask = freqs > 2000  # Above 2kHz
            high_energy = np.sum(magnitudes[high_freq_mask] ** 2)

            return float(high_energy / total_energy)
        except Exception:
            return 0.0
