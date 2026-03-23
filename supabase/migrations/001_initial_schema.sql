-- ============================================
-- Baby Monitor - Initial Database Schema
-- ============================================

-- ============================================
-- AUTHENTICATION & PROFILES
-- ============================================

-- Parent accounts (extends Supabase auth.users)
CREATE TABLE parent_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    email TEXT NOT NULL,
    pin_hash TEXT,                  -- PIN for device switching (when biometrics unavailable)
    setup_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Child profiles (multiple per parent)
CREATE TABLE child_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    date_of_birth DATE NOT NULL,
    avatar_url TEXT,
    filter_sensitivity JSONB DEFAULT '{
        "overstimulation": 5,
        "scariness": 3,
        "educational_preference": 5,
        "brainrot_tolerance": 3,
        "language_strictness": 8,
        "music_allowed": true,
        "max_video_duration_minutes": 30
    }'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Subscriptions (freemium)
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
    tier TEXT DEFAULT 'free' CHECK (tier IN ('free', 'premium')),
    monthly_analyses_used INTEGER DEFAULT 0,
    monthly_analyses_limit INTEGER DEFAULT 50,
    billing_period_start DATE DEFAULT CURRENT_DATE,
    billing_period_end DATE DEFAULT (CURRENT_DATE + INTERVAL '30 days'),
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(parent_id)
);

-- Registered devices
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,        -- unique per device installation (UUID generated on device)
    parent_id UUID NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
    device_name TEXT,
    platform TEXT,                  -- 'ios', 'android'
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(device_id)
);

-- ============================================
-- YOUTUBE CONTENT
-- ============================================

-- Channels (cached metadata)
CREATE TABLE yt_channels (
    channel_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    thumbnail_url TEXT,
    subscriber_count BIGINT,
    is_kids_channel BOOLEAN,
    global_trust_score REAL DEFAULT 0.5,
    last_fetched_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Videos (core content table)
CREATE TABLE yt_videos (
    video_id TEXT PRIMARY KEY,
    channel_id TEXT REFERENCES yt_channels(channel_id),
    title TEXT NOT NULL,
    description TEXT,
    thumbnail_url TEXT,
    duration_seconds INTEGER,
    published_at TIMESTAMPTZ,
    tags TEXT[],
    category_id INTEGER,
    has_captions BOOLEAN DEFAULT FALSE,
    view_count BIGINT,
    like_count BIGINT,
    analysis_status TEXT DEFAULT 'pending'
        CHECK (analysis_status IN ('pending', 'analyzing', 'completed', 'failed')),
    last_fetched_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- AI ANALYSIS RESULTS (Community-shared)
-- ============================================

CREATE TABLE video_analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id TEXT NOT NULL REFERENCES yt_videos(video_id) ON DELETE CASCADE,
    tiers_completed INTEGER[] DEFAULT '{}',
    -- Safety scores (1-10 scale)
    age_min_appropriate INTEGER DEFAULT 0,
    age_max_appropriate INTEGER DEFAULT 18,
    overstimulation_score REAL,
    educational_score REAL,
    scariness_score REAL,
    brainrot_score REAL,
    language_safety_score REAL,
    violence_score REAL,
    ad_commercial_score REAL,
    audio_safety_score REAL,
    -- Content labels and issues
    content_labels TEXT[] DEFAULT '{}',
    detected_issues TEXT[] DEFAULT '{}',
    analysis_reasoning TEXT,
    confidence REAL DEFAULT 0.0,
    -- Global moderation
    is_globally_blacklisted BOOLEAN DEFAULT FALSE,
    blacklist_reason TEXT,
    -- Metadata
    analyzed_by_user_id UUID REFERENCES parent_profiles(id),
    model_version TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(video_id)
);

-- Community votes on analysis accuracy
CREATE TABLE community_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id TEXT NOT NULL REFERENCES yt_videos(video_id) ON DELETE CASCADE,
    parent_id UUID NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
    rating TEXT CHECK (rating IN ('accurate', 'too_strict', 'too_lenient', 'dangerous')),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(video_id, parent_id)
);

-- Analysis queue for the Python worker
CREATE TABLE analysis_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id TEXT NOT NULL REFERENCES yt_videos(video_id) ON DELETE CASCADE,
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    requested_by UUID REFERENCES parent_profiles(id),
    status TEXT DEFAULT 'queued'
        CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
    worker_id TEXT,
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- ============================================
-- PARENT CURATION & OVERRIDES
-- ============================================

-- Per-parent channel preferences
CREATE TABLE parent_channel_prefs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
    channel_id TEXT NOT NULL REFERENCES yt_channels(channel_id) ON DELETE CASCADE,
    status TEXT CHECK (status IN ('approved', 'blocked')),
    applies_to_child_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(parent_id, channel_id, applies_to_child_id)
);

-- Per-parent video overrides
CREATE TABLE parent_video_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
    video_id TEXT NOT NULL REFERENCES yt_videos(video_id) ON DELETE CASCADE,
    status TEXT CHECK (status IN ('approved', 'blocked')),
    applies_to_child_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(parent_id, video_id, applies_to_child_id)
);

-- Content type preferences per child
CREATE TABLE content_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
    content_type TEXT NOT NULL,
    preference TEXT CHECK (preference IN ('preferred', 'allowed', 'blocked')),
    UNIQUE(child_id, content_type)
);

-- ============================================
-- SCREEN TIME
-- ============================================

CREATE TABLE screen_time_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
    mon_limit INTEGER,
    tue_limit INTEGER,
    wed_limit INTEGER,
    thu_limit INTEGER,
    fri_limit INTEGER,
    sat_limit INTEGER,
    sun_limit INTEGER,
    weekly_budget_minutes INTEGER,
    break_interval_minutes INTEGER DEFAULT 30,
    break_duration_minutes INTEGER DEFAULT 5,
    bedtime_hour INTEGER,
    bedtime_minute INTEGER,
    wakeup_hour INTEGER,
    wakeup_minute INTEGER,
    winddown_warning_minutes INTEGER DEFAULT 5,
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(child_id)
);

CREATE TABLE screen_time_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- CONTENT SCHEDULING (Premium)
-- ============================================

CREATE TABLE content_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
    day_of_week INTEGER,            -- 0=Mon..6=Sun, NULL=every day
    start_hour INTEGER NOT NULL,
    start_minute INTEGER DEFAULT 0,
    end_hour INTEGER NOT NULL,
    end_minute INTEGER DEFAULT 0,
    allowed_content_types TEXT[] NOT NULL,
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- WATCH HISTORY & ANALYTICS
-- ============================================

CREATE TABLE watch_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
    video_id TEXT NOT NULL REFERENCES yt_videos(video_id) ON DELETE CASCADE,
    watched_at TIMESTAMPTZ DEFAULT NOW(),
    watch_duration_seconds INTEGER,
    completed BOOLEAN DEFAULT FALSE
);

CREATE TABLE filtered_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
    video_id TEXT NOT NULL REFERENCES yt_videos(video_id) ON DELETE CASCADE,
    filter_reason TEXT NOT NULL,
    filtered_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- OFFLINE PLAYLISTS (Premium)
-- ============================================

CREATE TABLE offline_playlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
    child_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    video_ids TEXT[] DEFAULT '{}',
    device_id TEXT,
    auto_cleanup_days INTEGER DEFAULT 30,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_child_profiles_parent ON child_profiles(parent_id);
CREATE INDEX idx_devices_parent ON devices(parent_id);
CREATE INDEX idx_yt_videos_channel ON yt_videos(channel_id);
CREATE INDEX idx_yt_videos_analysis_status ON yt_videos(analysis_status);
CREATE INDEX idx_video_analyses_video_id ON video_analyses(video_id);
CREATE INDEX idx_video_analyses_scores ON video_analyses(age_min_appropriate, overstimulation_score, brainrot_score);
CREATE INDEX idx_community_ratings_video ON community_ratings(video_id);
CREATE INDEX idx_analysis_queue_status ON analysis_queue(status, priority, created_at);
CREATE INDEX idx_parent_channel_prefs_parent ON parent_channel_prefs(parent_id);
CREATE INDEX idx_parent_video_overrides_parent ON parent_video_overrides(parent_id);
CREATE INDEX idx_content_preferences_child ON content_preferences(child_id);
CREATE INDEX idx_screen_time_sessions_child ON screen_time_sessions(child_id, date);
CREATE INDEX idx_watch_history_child ON watch_history(child_id, watched_at DESC);
CREATE INDEX idx_filtered_log_child ON filtered_log(child_id, filtered_at DESC);
CREATE INDEX idx_content_schedules_child ON content_schedules(child_id);
CREATE INDEX idx_offline_playlists_parent ON offline_playlists(parent_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

-- Parent profiles: only own profile
ALTER TABLE parent_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile"
    ON parent_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile"
    ON parent_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile"
    ON parent_profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Child profiles: only own children
ALTER TABLE child_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Parents can manage own children"
    ON child_profiles FOR ALL USING (parent_id = auth.uid());

-- Subscriptions: only own
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own subscription"
    ON subscriptions FOR ALL USING (parent_id = auth.uid());

-- Devices: only own
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own devices"
    ON devices FOR ALL USING (parent_id = auth.uid());

-- YouTube content: readable by all authenticated
ALTER TABLE yt_channels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Channels readable by authenticated"
    ON yt_channels FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Service role can manage channels"
    ON yt_channels FOR ALL USING (auth.role() = 'service_role');

ALTER TABLE yt_videos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Videos readable by authenticated"
    ON yt_videos FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Service role can manage videos"
    ON yt_videos FOR ALL USING (auth.role() = 'service_role');

-- Video analyses: readable by all (community sharing!)
ALTER TABLE video_analyses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Analyses readable by authenticated"
    ON video_analyses FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Service role can manage analyses"
    ON video_analyses FOR ALL USING (auth.role() = 'service_role');

-- Community ratings: own ratings only for write
ALTER TABLE community_ratings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Ratings readable by authenticated"
    ON community_ratings FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Users can manage own ratings"
    ON community_ratings FOR INSERT WITH CHECK (parent_id = auth.uid());
CREATE POLICY "Users can update own ratings"
    ON community_ratings FOR UPDATE USING (parent_id = auth.uid());

-- Analysis queue: service role only
ALTER TABLE analysis_queue ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role manages queue"
    ON analysis_queue FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "Users can view own queue items"
    ON analysis_queue FOR SELECT USING (requested_by = auth.uid());
CREATE POLICY "Users can insert queue items"
    ON analysis_queue FOR INSERT WITH CHECK (requested_by = auth.uid());

-- Parent preferences: own only
ALTER TABLE parent_channel_prefs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own channel prefs"
    ON parent_channel_prefs FOR ALL USING (parent_id = auth.uid());

ALTER TABLE parent_video_overrides ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own video overrides"
    ON parent_video_overrides FOR ALL USING (parent_id = auth.uid());

-- Content preferences: via child ownership
ALTER TABLE content_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Parents can manage child content prefs"
    ON content_preferences FOR ALL
    USING (child_id IN (SELECT id FROM child_profiles WHERE parent_id = auth.uid()));

-- Screen time: via child ownership
ALTER TABLE screen_time_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Parents can manage child screen time rules"
    ON screen_time_rules FOR ALL
    USING (child_id IN (SELECT id FROM child_profiles WHERE parent_id = auth.uid()));

ALTER TABLE screen_time_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Parents can manage child screen time sessions"
    ON screen_time_sessions FOR ALL
    USING (child_id IN (SELECT id FROM child_profiles WHERE parent_id = auth.uid()));

-- Content schedules: via child ownership
ALTER TABLE content_schedules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Parents can manage child content schedules"
    ON content_schedules FOR ALL
    USING (child_id IN (SELECT id FROM child_profiles WHERE parent_id = auth.uid()));

-- Watch history: via child ownership
ALTER TABLE watch_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Parents can manage child watch history"
    ON watch_history FOR ALL
    USING (child_id IN (SELECT id FROM child_profiles WHERE parent_id = auth.uid()));

ALTER TABLE filtered_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Parents can view child filtered log"
    ON filtered_log FOR SELECT
    USING (child_id IN (SELECT id FROM child_profiles WHERE parent_id = auth.uid()));
CREATE POLICY "Service role can insert filtered log"
    ON filtered_log FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- Offline playlists: own only
ALTER TABLE offline_playlists ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own playlists"
    ON offline_playlists FOR ALL USING (parent_id = auth.uid());

-- ============================================
-- FUNCTIONS
-- ============================================

-- Auto-create parent profile and subscription on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO parent_profiles (id, display_name, email)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
        NEW.email
    );
    INSERT INTO subscriptions (parent_id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_parent_profiles_timestamp
    BEFORE UPDATE ON parent_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_child_profiles_timestamp
    BEFORE UPDATE ON child_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_subscriptions_timestamp
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_video_analyses_timestamp
    BEFORE UPDATE ON video_analyses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_screen_time_rules_timestamp
    BEFORE UPDATE ON screen_time_rules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_offline_playlists_timestamp
    BEFORE UPDATE ON offline_playlists
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
