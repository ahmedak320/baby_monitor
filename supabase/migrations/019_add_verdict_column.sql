-- Add verdict column to video_analyses.
-- The worker result_writer stores the analysis verdict (approve/reject/needs_visual_review/etc.)
-- and tier0_cache reads it for cache lookups. Without this column, result_writer silently fails.

ALTER TABLE public.video_analyses
    ADD COLUMN IF NOT EXISTS verdict TEXT;

-- Backfill existing rows: derive verdict from confidence + blacklist status
UPDATE public.video_analyses
SET verdict = CASE
    WHEN is_globally_blacklisted THEN 'reject'
    WHEN confidence >= 0.7 THEN 'approve'
    ELSE 'needs_visual_review'
END
WHERE verdict IS NULL;

-- Index for filtering by verdict
CREATE INDEX IF NOT EXISTS idx_video_analyses_verdict
    ON public.video_analyses (verdict);
