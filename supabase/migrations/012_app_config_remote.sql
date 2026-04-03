-- Migration 012: Remote app configuration table + cache TTL indexes

-- 1. Create app_config table for remote configuration
CREATE TABLE IF NOT EXISTS app_config (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read config
CREATE POLICY "Authenticated users can read app_config"
    ON app_config FOR SELECT
    TO authenticated
    USING (true);

-- Service role has full access
CREATE POLICY "Service role has full access to app_config"
    ON app_config FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 3. Seed default rows
INSERT INTO app_config (key, value) VALUES
    ('youtube_api_keys', '[]'::jsonb),
    ('piped_instances', '[]'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- 4. Auto-update updated_at on UPDATE
-- Reuses update_updated_at() function from migration 001_initial_schema.sql
CREATE TRIGGER update_app_config_timestamp
    BEFORE UPDATE ON app_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 5. Indexes for cache TTL queries on existing tables
CREATE INDEX IF NOT EXISTS idx_yt_videos_last_fetched ON yt_videos(last_fetched_at);
CREATE INDEX IF NOT EXISTS idx_yt_channels_last_fetched ON yt_channels(last_fetched_at);
