-- Testing helpers: temporary functions for development/testing.
-- To be removed or secured before production launch.

-- Allow users to toggle their subscription tier (bypasses RLS tier restriction).
CREATE OR REPLACE FUNCTION set_subscription_tier(new_tier TEXT)
RETURNS void AS $$
BEGIN
  IF new_tier NOT IN ('free', 'premium') THEN
    RAISE EXCEPTION 'Invalid tier: %', new_tier;
  END IF;

  UPDATE subscriptions
  SET tier = new_tier,
      monthly_analyses_limit = CASE WHEN new_tier = 'premium' THEN 999999 ELSE 50 END,
      updated_at = NOW()
  WHERE parent_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Allow app to log filtered content (bypasses service_role-only INSERT on filtered_log).
CREATE OR REPLACE FUNCTION log_filtered_content(
  p_child_id UUID,
  p_video_id TEXT,
  p_reason TEXT
)
RETURNS void AS $$
BEGIN
  -- Verify the child belongs to the calling user
  IF NOT EXISTS (
    SELECT 1 FROM child_profiles WHERE id = p_child_id AND parent_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Child does not belong to current user';
  END IF;

  -- Avoid duplicate entries for the same child+video within 1 hour
  IF EXISTS (
    SELECT 1 FROM filtered_log
    WHERE child_id = p_child_id
      AND video_id = p_video_id
      AND filtered_at > NOW() - INTERVAL '1 hour'
  ) THEN
    RETURN;
  END IF;

  INSERT INTO filtered_log (child_id, video_id, filter_reason)
  VALUES (p_child_id, p_video_id, p_reason);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
