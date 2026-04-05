-- Ensure metadata_approved videos always get queued for full AI analysis.
-- The metadata gate is a temporary fast-pass for UX continuity — every video
-- must eventually go through the real analysis pipeline.

-- Trigger function: when a video is set to metadata_approved, queue it for
-- full analysis if not already queued/processing.
CREATE OR REPLACE FUNCTION public.queue_metadata_approved_video()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.analysis_status = 'metadata_approved'
       AND (OLD.analysis_status IS DISTINCT FROM 'metadata_approved')
    THEN
        INSERT INTO analysis_queue (video_id, priority, source)
        SELECT NEW.video_id, 6, 'metadata_upgrade'
        WHERE NOT EXISTS (
            SELECT 1 FROM analysis_queue
            WHERE video_id = NEW.video_id
              AND status IN ('queued', 'processing')
        );
    END IF;
    RETURN NEW;
END;
$$;

-- Fire after any update that sets analysis_status to metadata_approved
DROP TRIGGER IF EXISTS trg_queue_metadata_approved ON yt_videos;
CREATE TRIGGER trg_queue_metadata_approved
    AFTER INSERT OR UPDATE OF analysis_status ON yt_videos
    FOR EACH ROW
    WHEN (NEW.analysis_status = 'metadata_approved')
    EXECUTE FUNCTION queue_metadata_approved_video();
