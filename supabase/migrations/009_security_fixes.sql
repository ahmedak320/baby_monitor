-- ============================================
-- 009: Security Fixes
-- ============================================
-- This migration addresses all known database security vulnerabilities:
--
--   1. Add pin_salt column to parent_profiles for secure PIN hashing
--   2. Fix delete_parent_account: auth check, correct column names, complete cascade
--   3. Fix increment_analysis_usage: remove parameter, use auth.uid()
--   4. Fix delete_child_data: ownership check, complete cascade
--   5. Fix match_video_embeddings: replace nonexistent verdict column
--   6. Add SET search_path = public to ALL SECURITY DEFINER functions
--   7. Enforce rate limit functions in RLS policies
--   8. Add DELETE policy on community_ratings
--   9. Restrict subscription updates to prevent tier manipulation
-- ============================================


-- ============================================
-- 1. Add pin_salt column
-- ============================================

ALTER TABLE parent_profiles ADD COLUMN IF NOT EXISTS pin_salt TEXT;


-- ============================================
-- 2. Fix delete_parent_account
--    - Add auth check (can only delete own account)
--    - Loop through children and call delete_child_data for each
--    - Delete from ALL parent-level tables
--    - Fix column names (parent_id, not user_id; id, not user_id)
--    - Add SET search_path = public
-- ============================================

CREATE OR REPLACE FUNCTION delete_parent_account(target_user_id UUID)
RETURNS void AS $$
DECLARE
  child_record RECORD;
BEGIN
  -- Auth check: users can only delete their own account
  IF target_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Not authorized: can only delete own account';
  END IF;

  -- Delete all child profiles and their associated data
  FOR child_record IN
    SELECT id FROM child_profiles WHERE parent_id = target_user_id
  LOOP
    PERFORM delete_child_data(child_record.id);
  END LOOP;

  -- Nullify references in shared tables to prevent FK violations
  UPDATE video_analyses SET analyzed_by_user_id = NULL WHERE analyzed_by_user_id = target_user_id;
  DELETE FROM analysis_queue WHERE requested_by = target_user_id;

  -- Delete parent-level data from all tables
  DELETE FROM community_ratings WHERE parent_id = target_user_id;
  DELETE FROM analytics_events WHERE user_id = target_user_id;
  DELETE FROM parent_link_submissions WHERE parent_id = target_user_id;
  DELETE FROM beta_feedback WHERE parent_id = target_user_id;
  DELETE FROM offline_playlists WHERE parent_id = target_user_id;
  DELETE FROM parent_channel_prefs WHERE parent_id = target_user_id;
  DELETE FROM parent_video_overrides WHERE parent_id = target_user_id;
  DELETE FROM devices WHERE parent_id = target_user_id;
  DELETE FROM subscriptions WHERE parent_id = target_user_id;
  DELETE FROM parent_profiles WHERE id = target_user_id;

  -- Note: auth.users row must be deleted via Supabase Admin API or edge function.
  -- The app should call supabase.auth.admin.deleteUser() from a server-side context
  -- after this function completes.
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ============================================
-- 3. Fix increment_analysis_usage
--    - Remove parameter, use auth.uid() directly
--    - Add SET search_path = public
-- ============================================

-- Drop the old vulnerable version that accepted a user_id parameter
DROP FUNCTION IF EXISTS increment_analysis_usage(UUID);

CREATE OR REPLACE FUNCTION increment_analysis_usage()
RETURNS void AS $$
BEGIN
    UPDATE subscriptions
    SET monthly_analyses_used = monthly_analyses_used + 1, updated_at = NOW()
    WHERE parent_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ============================================
-- 4. Fix delete_child_data
--    - Add ownership check (child's parent_id must equal auth.uid())
--    - Add missing DELETEs: video_interruptions, content_schedules, offline_playlists
--    - Keep existing DELETEs
--    - Add SET search_path = public
-- ============================================

CREATE OR REPLACE FUNCTION delete_child_data(target_child_id UUID)
RETURNS void AS $$
BEGIN
  -- Ownership check: verify the child belongs to the calling user
  IF NOT EXISTS (
    SELECT 1 FROM child_profiles WHERE id = target_child_id AND parent_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Not authorized: child does not belong to current user';
  END IF;

  -- Delete all child-associated data
  DELETE FROM video_interruptions WHERE child_id = target_child_id;
  DELETE FROM content_schedules WHERE child_id = target_child_id;
  DELETE FROM offline_playlists WHERE child_id = target_child_id;
  DELETE FROM watch_history WHERE child_id = target_child_id;
  DELETE FROM filtered_log WHERE child_id = target_child_id;
  DELETE FROM screen_time_sessions WHERE child_id = target_child_id;
  DELETE FROM screen_time_rules WHERE child_id = target_child_id;
  DELETE FROM content_preferences WHERE child_id = target_child_id;
  DELETE FROM child_profiles WHERE id = target_child_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ============================================
-- 5. Fix match_video_embeddings
--    - Replace nonexistent va.verdict column with CASE expression
--    - Add SET search_path = public
-- ============================================

CREATE OR REPLACE FUNCTION match_video_embeddings(
  query_embedding vector(768),
  match_threshold float DEFAULT 0.85,
  match_count int DEFAULT 5
)
RETURNS TABLE (
  video_id text,
  verdict text,
  similarity float
)
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT
    va.video_id,
    CASE
      WHEN va.is_globally_blacklisted THEN 'reject'
      WHEN va.confidence >= 0.85 THEN 'approve'
      ELSE 'needs_review'
    END as verdict,
    1 - (va.embedding <=> query_embedding) as similarity
  FROM video_analyses va
  WHERE va.embedding IS NOT NULL
    AND 1 - (va.embedding <=> query_embedding) > match_threshold
  ORDER BY va.embedding <=> query_embedding
  LIMIT match_count;
$$;


-- ============================================
-- 6. Add SET search_path = public to ALL remaining
--    SECURITY DEFINER functions
-- ============================================

-- 6a. handle_new_user() — from 001
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 6b. update_channel_trust_scores() — from 002
CREATE OR REPLACE FUNCTION update_channel_trust_scores()
RETURNS void AS $$
BEGIN
    UPDATE yt_channels c
    SET global_trust_score = sub.avg_confidence
    FROM (
        SELECT
            v.channel_id,
            AVG(a.confidence) as avg_confidence
        FROM yt_videos v
        JOIN video_analyses a ON a.video_id = v.video_id
        WHERE v.channel_id IS NOT NULL
          AND a.confidence > 0
        GROUP BY v.channel_id
        HAVING COUNT(*) >= 3  -- Only update if 3+ videos analyzed
    ) sub
    WHERE c.channel_id = sub.channel_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 6c. reset_monthly_analysis_counters() — from 002
CREATE OR REPLACE FUNCTION reset_monthly_analysis_counters()
RETURNS void AS $$
BEGIN
    UPDATE subscriptions
    SET monthly_analyses_used = 0,
        billing_period_start = CURRENT_DATE,
        billing_period_end = CURRENT_DATE + INTERVAL '30 days',
        updated_at = NOW()
    WHERE billing_period_end <= CURRENT_DATE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 6d. get_community_consensus(vid TEXT) — from 002
CREATE OR REPLACE FUNCTION get_community_consensus(vid TEXT)
RETURNS TABLE(
    total_votes BIGINT,
    accurate_count BIGINT,
    too_strict_count BIGINT,
    too_lenient_count BIGINT,
    dangerous_count BIGINT,
    consensus TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*) as total_votes,
        COUNT(*) FILTER (WHERE cr.rating = 'accurate') as accurate_count,
        COUNT(*) FILTER (WHERE cr.rating = 'too_strict') as too_strict_count,
        COUNT(*) FILTER (WHERE cr.rating = 'too_lenient') as too_lenient_count,
        COUNT(*) FILTER (WHERE cr.rating = 'dangerous') as dangerous_count,
        (
            SELECT cr2.rating
            FROM community_ratings cr2
            WHERE cr2.video_id = vid
            GROUP BY cr2.rating
            ORDER BY COUNT(*) DESC
            LIMIT 1
        ) as consensus
    FROM community_ratings cr
    WHERE cr.video_id = vid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 6e. check_rating_rate_limit(user_id UUID) — from 007
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- 6f. check_queue_limit(user_id UUID) — from 007
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
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- 6g. cleanup_old_watch_history() — from 007
--     Note: original was not SECURITY DEFINER, adding it with search_path
CREATE OR REPLACE FUNCTION cleanup_old_watch_history()
RETURNS void AS $$
BEGIN
  DELETE FROM watch_history
  WHERE watched_at < now() - INTERVAL '1 year';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ============================================
-- 7. Enforce rate limit functions in RLS policies
-- ============================================

-- 7a. community_ratings: drop old INSERT policy, create separate INSERT and UPDATE
DROP POLICY IF EXISTS "Users can manage own ratings" ON community_ratings;
DROP POLICY IF EXISTS "Users can update own ratings" ON community_ratings;

CREATE POLICY "Users can insert own ratings" ON community_ratings FOR INSERT
  WITH CHECK (parent_id = auth.uid() AND check_rating_rate_limit(auth.uid()));

CREATE POLICY "Users can update own ratings" ON community_ratings FOR UPDATE
  USING (parent_id = auth.uid());

-- 7b. analysis_queue: drop old INSERT policy, create rate-limited one
DROP POLICY IF EXISTS "Users can insert queue items" ON analysis_queue;

CREATE POLICY "Users can insert queue items" ON analysis_queue FOR INSERT
  WITH CHECK (requested_by = auth.uid() AND check_queue_limit(auth.uid()));


-- ============================================
-- 8. Add DELETE policy on community_ratings
-- ============================================

CREATE POLICY "Users can delete own ratings" ON community_ratings FOR DELETE
  USING (parent_id = auth.uid());


-- ============================================
-- 9. Restrict subscription updates (prevent tier manipulation)
--    Drop existing broad policy; create granular SELECT, UPDATE, and service_role ALL
-- ============================================

DROP POLICY IF EXISTS "Users can manage own subscription" ON subscriptions;

-- Users can read their own subscription
CREATE POLICY "Users can view own subscription" ON subscriptions FOR SELECT
  USING (parent_id = auth.uid());

-- Users can update their own subscription, but cannot change tier or monthly_analyses_limit
CREATE POLICY "Users can update own subscription" ON subscriptions FOR UPDATE
  USING (parent_id = auth.uid())
  WITH CHECK (
    parent_id = auth.uid()
    AND tier = (SELECT s.tier FROM subscriptions s WHERE s.parent_id = auth.uid())
    AND monthly_analyses_limit = (SELECT s.monthly_analyses_limit FROM subscriptions s WHERE s.parent_id = auth.uid())
  );

-- Service role has full access (for backend/worker operations)
CREATE POLICY "Service role can manage subscriptions" ON subscriptions FOR ALL
  USING (auth.role() = 'service_role');
