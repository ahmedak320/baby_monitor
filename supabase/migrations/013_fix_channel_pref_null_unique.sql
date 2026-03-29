-- Fix: PostgreSQL UNIQUE constraint treats NULL != NULL, allowing duplicate
-- rows in parent_channel_prefs when applies_to_child_id IS NULL.
-- This adds a partial unique index covering that case.

-- Clean up any existing duplicates (keep newest)
DELETE FROM parent_channel_prefs a
USING parent_channel_prefs b
WHERE a.parent_id = b.parent_id
  AND a.channel_id = b.channel_id
  AND a.applies_to_child_id IS NULL
  AND b.applies_to_child_id IS NULL
  AND a.created_at < b.created_at;

-- Partial unique index for NULL applies_to_child_id
CREATE UNIQUE INDEX IF NOT EXISTS idx_parent_channel_prefs_no_child
  ON parent_channel_prefs(parent_id, channel_id)
  WHERE applies_to_child_id IS NULL;
