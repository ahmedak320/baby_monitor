-- Rate limiting and anti-gaming measures

-- Add rated_at timestamp for rate limit checks
ALTER TABLE community_ratings
  ADD COLUMN IF NOT EXISTS rated_at TIMESTAMPTZ DEFAULT now();

-- Function to check community rating rate limit (max 100/day per user)
CREATE OR REPLACE FUNCTION check_rating_rate_limit(user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  rating_count INT;
BEGIN
  SELECT COUNT(*)
  INTO rating_count
  FROM community_ratings
  WHERE parent_id = user_id
    AND rated_at > now() - INTERVAL '24 hours';

  RETURN rating_count < 100;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Function to check analysis queue limit (max 20 pending per user)
CREATE OR REPLACE FUNCTION check_queue_limit(user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  queue_count INT;
BEGIN
  SELECT COUNT(*)
  INTO queue_count
  FROM analysis_queue
  WHERE requested_by = user_id
    AND status IN ('queued', 'processing');

  RETURN queue_count < 20;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Data retention: auto-delete watch history older than 1 year
-- Run via pg_cron or manual scheduled task
CREATE OR REPLACE FUNCTION cleanup_old_watch_history()
RETURNS void AS $$
BEGIN
  DELETE FROM watch_history
  WHERE watched_at < now() - INTERVAL '1 year';
END;
$$ LANGUAGE plpgsql;

-- Function to cascade-delete all child data (COPPA: right to delete)
CREATE OR REPLACE FUNCTION delete_child_data(target_child_id UUID)
RETURNS void AS $$
BEGIN
  DELETE FROM watch_history WHERE child_id = target_child_id;
  DELETE FROM filtered_log WHERE child_id = target_child_id;
  DELETE FROM screen_time_sessions WHERE child_id = target_child_id;
  DELETE FROM screen_time_rules WHERE child_id = target_child_id;
  DELETE FROM content_preferences WHERE child_id = target_child_id;
  DELETE FROM child_profiles WHERE id = target_child_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
