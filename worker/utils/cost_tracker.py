"""Track AI API costs per video analysis."""

import logging
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


@dataclass
class AnalysisCost:
    """Track costs for a single video analysis."""

    video_id: str
    tier1_cost: float = 0.0
    tier2_cost: float = 0.0
    tier3_cost: float = 0.0

    @property
    def total_cost(self) -> float:
        return self.tier1_cost + self.tier2_cost + self.tier3_cost

    def log_summary(self) -> None:
        logger.info(
            "Cost for %s: T1=$%.4f T2=$%.4f T3=$%.4f Total=$%.4f",
            self.video_id,
            self.tier1_cost,
            self.tier2_cost,
            self.tier3_cost,
            self.total_cost,
        )
