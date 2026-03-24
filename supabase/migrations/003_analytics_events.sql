-- ============================================
-- Beta Analytics Events
-- ============================================

CREATE TABLE analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES parent_profiles(id) ON DELETE SET NULL,
    event_name TEXT NOT NULL,
    properties JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_analytics_events_name ON analytics_events(event_name, created_at DESC);
CREATE INDEX idx_analytics_events_user ON analytics_events(user_id, created_at DESC);

-- Allow authenticated users to insert events
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can insert own events"
    ON analytics_events FOR INSERT
    WITH CHECK (user_id = auth.uid());
CREATE POLICY "Service role can read all events"
    ON analytics_events FOR SELECT
    USING (auth.role() = 'service_role');

-- ============================================
-- Beta Feedback
-- ============================================

CREATE TABLE beta_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN (
        'bug', 'feature_request', 'content_issue', 'usability', 'general'
    )),
    message TEXT NOT NULL,
    app_version TEXT,
    device_info TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_beta_feedback_parent ON beta_feedback(parent_id);
CREATE INDEX idx_beta_feedback_category ON beta_feedback(category, created_at DESC);

ALTER TABLE beta_feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can insert own feedback"
    ON beta_feedback FOR INSERT
    WITH CHECK (parent_id = auth.uid());
CREATE POLICY "Users can view own feedback"
    ON beta_feedback FOR SELECT
    USING (parent_id = auth.uid());
CREATE POLICY "Service role can manage feedback"
    ON beta_feedback FOR ALL
    USING (auth.role() = 'service_role');
