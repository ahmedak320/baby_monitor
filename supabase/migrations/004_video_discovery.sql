-- ============================================
-- Video Discovery & Live Filtering Pipeline
-- ============================================

-- Extend yt_videos with discovery metadata
ALTER TABLE yt_videos
    DROP CONSTRAINT IF EXISTS yt_videos_analysis_status_check;

ALTER TABLE yt_videos
    ADD CONSTRAINT yt_videos_analysis_status_check
    CHECK (analysis_status IN ('pending', 'analyzing', 'completed', 'failed', 'metadata_approved'));

ALTER TABLE yt_videos
    ADD COLUMN IF NOT EXISTS discovery_source TEXT DEFAULT 'seed',
    ADD COLUMN IF NOT EXISTS is_short BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS metadata_gate_passed BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS metadata_gate_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_yt_videos_discovery_source ON yt_videos(discovery_source);
CREATE INDEX IF NOT EXISTS idx_yt_videos_is_short ON yt_videos(is_short);
CREATE INDEX IF NOT EXISTS idx_yt_videos_metadata_gate ON yt_videos(metadata_gate_passed, analysis_status);

-- Extend analysis_queue with source tracking and progress
ALTER TABLE analysis_queue
    ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'manual',
    ADD COLUMN IF NOT EXISTS progress JSONB DEFAULT '{}';

-- ============================================
-- Video Interruptions (when analysis rejects mid-play)
-- ============================================

CREATE TABLE video_interruptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
    video_id TEXT NOT NULL REFERENCES yt_videos(video_id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    watch_seconds_before_interrupt INTEGER DEFAULT 0,
    interrupted_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_video_interruptions_child ON video_interruptions(child_id, interrupted_at DESC);

ALTER TABLE video_interruptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can insert child interruptions"
    ON video_interruptions FOR INSERT
    WITH CHECK (child_id IN (
        SELECT id FROM child_profiles WHERE parent_id = auth.uid()
    ));
CREATE POLICY "Users can view child interruptions"
    ON video_interruptions FOR SELECT
    USING (child_id IN (
        SELECT id FROM child_profiles WHERE parent_id = auth.uid()
    ));

-- ============================================
-- Parent Link Submissions
-- ============================================

CREATE TABLE parent_link_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    video_id TEXT,
    action TEXT NOT NULL CHECK (action IN ('analyze', 'approve', 'block')),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_parent_link_submissions_parent ON parent_link_submissions(parent_id, created_at DESC);

ALTER TABLE parent_link_submissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own submissions"
    ON parent_link_submissions FOR ALL
    USING (parent_id = auth.uid());
