-- Add is_short column to yt_videos for efficient Shorts queries
ALTER TABLE yt_videos ADD COLUMN IF NOT EXISTS is_short BOOLEAN DEFAULT false;

-- Backfill: mark existing short videos
UPDATE yt_videos
SET is_short = true
WHERE duration_seconds <= 60
   OR title ILIKE '%#shorts%'
   OR title ILIKE '% shorts%';

-- Partial index for quick Shorts lookups
CREATE INDEX IF NOT EXISTS idx_yt_videos_is_short
  ON yt_videos(is_short) WHERE is_short = true;
