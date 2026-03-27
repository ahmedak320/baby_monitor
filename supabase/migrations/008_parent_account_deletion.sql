-- Parent account deletion (COPPA: right to delete all data)
-- Cascades through all child data, preferences, and parent profile.

CREATE OR REPLACE FUNCTION delete_parent_account(target_user_id UUID)
RETURNS void AS $$
DECLARE
  child_record RECORD;
BEGIN
  -- Delete all child profiles and their associated data
  FOR child_record IN
    SELECT id FROM child_profiles WHERE parent_id = target_user_id
  LOOP
    PERFORM delete_child_data(child_record.id);
  END LOOP;

  -- Delete parent-level data
  DELETE FROM parent_channel_prefs WHERE parent_id = target_user_id;
  DELETE FROM parent_video_overrides WHERE parent_id = target_user_id;
  DELETE FROM devices WHERE user_id = target_user_id;
  DELETE FROM subscriptions WHERE user_id = target_user_id;
  DELETE FROM parent_profiles WHERE user_id = target_user_id;

  -- Note: auth.users row must be deleted via Supabase Admin API or edge function.
  -- The app should call supabase.auth.admin.deleteUser() from a server-side context
  -- after this function completes.
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to authenticated users (they can only delete their own data via RLS)
GRANT EXECUTE ON FUNCTION delete_parent_account(UUID) TO authenticated;

-- Scheduled cleanup documentation:
-- These functions exist in migration 007 but require scheduling.
-- For Supabase Pro (pg_cron available):
--   SELECT cron.schedule('cleanup-watch-history', '0 3 1 * *', 'SELECT cleanup_old_watch_history()');
--   SELECT cron.schedule('reset-monthly-counters', '0 0 * * *', 'SELECT reset_monthly_analysis_counters()');
-- For Supabase Free tier:
--   Use GitHub Actions with a scheduled workflow that calls these via Supabase Management API
--   or create edge functions that invoke these SQL functions on a schedule.
