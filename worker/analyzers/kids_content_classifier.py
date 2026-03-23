"""Kids content quality classifier.

Detects Elsagate-style disturbing content disguised as children's videos.
Based on heuristic patterns from the Disturbed YouTube for Kids Classifier.
"""

import logging
import re

logger = logging.getLogger(__name__)

# Keywords commonly found in disturbing kids content
ELSAGATE_KEYWORDS = {
    "high_risk": [
        "elsa", "spiderman", "joker", "prank", "injection", "needle",
        "pregnant", "surgery", "toilet", "skibidi", "huggy wuggy",
        "poppy playtime", "granny", "horror", "scary", "creepy",
        "slime", "mukbang", "asmr eat",
    ],
    "medium_risk": [
        "challenge", "dare", "gone wrong", "3am", "calling",
        "mystery", "sus", "among us real life", "squid game",
        "fnaf", "five nights", "backrooms",
    ],
    "brainrot_indicators": [
        "skibidi", "ohio", "rizz", "gyatt", "fanum tax",
        "sigma", "alpha male", "only in ohio", "grimace shake",
        "among us", "sussy", "sus",
    ],
}

# Title patterns that indicate low-quality or concerning content
CONCERNING_PATTERNS = [
    r"(?i)gone\s+(wrong|sexual|violent)",
    r"(?i)(3|three)\s*am\s+challenge",
    r"(?i)do\s+not\s+(call|watch|play)\s+at",
    r"(?i)caught\s+on\s+camera",
    r"(?i)(real|actual)\s+ghost",
    r"(?i)creepypasta",
    r"(?i)most\s+disturbing",
]


class KidsContentClassifier:
    """Classify content quality for kids."""

    def analyze_metadata(
        self,
        title: str,
        description: str,
        tags: list[str],
        channel_title: str = "",
    ) -> dict:
        """Analyze video metadata for kids content safety.

        Returns dict with:
        - elsagate_risk: 0-1 (disturbing content disguised as kids)
        - brainrot_score: 0-1 (mindless, repetitive content)
        - quality_score: 0-1 (overall content quality estimate)
        - flags: list of specific concerns
        """
        combined_text = f"{title} {description} {' '.join(tags)} {channel_title}".lower()
        flags = []

        # Check Elsagate keywords
        high_risk_count = sum(
            1 for kw in ELSAGATE_KEYWORDS["high_risk"] if kw in combined_text
        )
        medium_risk_count = sum(
            1 for kw in ELSAGATE_KEYWORDS["medium_risk"] if kw in combined_text
        )

        if high_risk_count >= 2:
            flags.append(f"elsagate_keywords_high_x{high_risk_count}")
        if medium_risk_count >= 2:
            flags.append(f"elsagate_keywords_medium_x{medium_risk_count}")

        # Check brainrot indicators
        brainrot_count = sum(
            1 for kw in ELSAGATE_KEYWORDS["brainrot_indicators"]
            if kw in combined_text
        )
        if brainrot_count >= 2:
            flags.append(f"brainrot_keywords_x{brainrot_count}")

        # Check concerning patterns
        for pattern in CONCERNING_PATTERNS:
            if re.search(pattern, title + " " + description):
                flags.append(f"concerning_pattern: {pattern}")
                break

        # Check for clickbait patterns in title
        if title.upper() == title and len(title) > 10:
            flags.append("all_caps_title")
        if title.count("!") >= 3 or title.count("?") >= 3:
            flags.append("excessive_punctuation")

        # Calculate scores
        elsagate_risk = min(1.0, (high_risk_count * 0.3 + medium_risk_count * 0.15))
        brainrot_score = min(1.0, brainrot_count * 0.25)

        quality_penalty = (
            elsagate_risk * 0.5
            + brainrot_score * 0.3
            + (0.1 if "all_caps_title" in flags else 0)
            + (0.1 if "excessive_punctuation" in flags else 0)
        )
        quality_score = max(0.0, 1.0 - quality_penalty)

        return {
            "elsagate_risk": elsagate_risk,
            "brainrot_score": brainrot_score,
            "quality_score": quality_score,
            "flags": flags,
        }
