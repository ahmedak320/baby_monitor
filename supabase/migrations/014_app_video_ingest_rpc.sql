-- Backend-owned ingestion for app-originated video discovery/cache writes.

CREATE OR REPLACE FUNCTION ingest_video_cache_entry(
    p_video_id TEXT,
    p_title TEXT,
    p_channel_id TEXT DEFAULT NULL,
    p_channel_title TEXT DEFAULT NULL,
    p_description TEXT DEFAULT '',
    p_thumbnail_url TEXT DEFAULT '',
    p_duration_seconds INTEGER DEFAULT 0,
    p_published_at TIMESTAMPTZ DEFAULT NULL,
    p_tags TEXT[] DEFAULT '{}'::TEXT[],
    p_category_id INTEGER DEFAULT 0,
    p_has_captions BOOLEAN DEFAULT FALSE,
    p_view_count BIGINT DEFAULT 0,
    p_like_count BIGINT DEFAULT 0,
    p_is_short BOOLEAN DEFAULT FALSE,
    p_discovery_source TEXT DEFAULT 'manual',
    p_analysis_status TEXT DEFAULT 'pending',
    p_metadata_gate_passed BOOLEAN DEFAULT FALSE,
    p_metadata_gate_reason TEXT DEFAULT NULL,
    p_queue_priority INTEGER DEFAULT NULL,
    p_queue_source TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_requested_by UUID := auth.uid();
    v_channel_id TEXT := NULLIF(TRIM(COALESCE(p_channel_id, '')), '');
    v_channel_title TEXT := NULLIF(TRIM(COALESCE(p_channel_title, '')), '');
BEGIN
    IF v_requested_by IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF TRIM(COALESCE(p_video_id, '')) = '' THEN
        RAISE EXCEPTION 'p_video_id is required';
    END IF;

    IF TRIM(COALESCE(p_title, '')) = '' THEN
        RAISE EXCEPTION 'p_title is required';
    END IF;

    IF v_channel_id IS NOT NULL THEN
        INSERT INTO yt_channels (
            channel_id,
            title,
            last_fetched_at
        )
        VALUES (
            v_channel_id,
            COALESCE(v_channel_title, 'Unknown Channel'),
            NOW()
        )
        ON CONFLICT (channel_id) DO UPDATE
        SET title = COALESCE(
                NULLIF(EXCLUDED.title, ''),
                yt_channels.title,
                'Unknown Channel'
            ),
            last_fetched_at = NOW();
    END IF;

    INSERT INTO yt_videos (
        video_id,
        channel_id,
        title,
        description,
        thumbnail_url,
        duration_seconds,
        published_at,
        tags,
        category_id,
        has_captions,
        view_count,
        like_count,
        analysis_status,
        discovery_source,
        is_short,
        metadata_gate_passed,
        metadata_gate_reason,
        last_fetched_at
    )
    VALUES (
        p_video_id,
        v_channel_id,
        p_title,
        COALESCE(p_description, ''),
        COALESCE(p_thumbnail_url, ''),
        COALESCE(p_duration_seconds, 0),
        p_published_at,
        COALESCE(p_tags, '{}'::TEXT[]),
        COALESCE(p_category_id, 0),
        COALESCE(p_has_captions, FALSE),
        COALESCE(p_view_count, 0),
        COALESCE(p_like_count, 0),
        COALESCE(p_analysis_status, 'pending'),
        COALESCE(p_discovery_source, 'manual'),
        COALESCE(p_is_short, FALSE),
        COALESCE(p_metadata_gate_passed, FALSE),
        p_metadata_gate_reason,
        NOW()
    )
    ON CONFLICT (video_id) DO UPDATE
    SET channel_id = COALESCE(EXCLUDED.channel_id, yt_videos.channel_id),
        title = CASE
            WHEN NULLIF(EXCLUDED.title, '') IS NOT NULL THEN EXCLUDED.title
            ELSE yt_videos.title
        END,
        description = CASE
            WHEN NULLIF(EXCLUDED.description, '') IS NOT NULL THEN EXCLUDED.description
            ELSE yt_videos.description
        END,
        thumbnail_url = CASE
            WHEN NULLIF(EXCLUDED.thumbnail_url, '') IS NOT NULL THEN EXCLUDED.thumbnail_url
            ELSE yt_videos.thumbnail_url
        END,
        duration_seconds = GREATEST(COALESCE(EXCLUDED.duration_seconds, 0), COALESCE(yt_videos.duration_seconds, 0)),
        published_at = COALESCE(EXCLUDED.published_at, yt_videos.published_at),
        tags = CASE
            WHEN array_length(EXCLUDED.tags, 1) IS NOT NULL THEN EXCLUDED.tags
            ELSE yt_videos.tags
        END,
        category_id = CASE
            WHEN COALESCE(EXCLUDED.category_id, 0) <> 0 THEN EXCLUDED.category_id
            ELSE yt_videos.category_id
        END,
        has_captions = COALESCE(EXCLUDED.has_captions, yt_videos.has_captions),
        view_count = GREATEST(COALESCE(EXCLUDED.view_count, 0), COALESCE(yt_videos.view_count, 0)),
        like_count = GREATEST(COALESCE(EXCLUDED.like_count, 0), COALESCE(yt_videos.like_count, 0)),
        analysis_status = CASE
            WHEN yt_videos.analysis_status = 'completed' THEN yt_videos.analysis_status
            WHEN yt_videos.analysis_status = 'metadata_approved' AND EXCLUDED.analysis_status = 'pending' THEN yt_videos.analysis_status
            ELSE COALESCE(EXCLUDED.analysis_status, yt_videos.analysis_status)
        END,
        discovery_source = COALESCE(EXCLUDED.discovery_source, yt_videos.discovery_source),
        is_short = COALESCE(yt_videos.is_short, FALSE) OR COALESCE(EXCLUDED.is_short, FALSE),
        metadata_gate_passed = COALESCE(yt_videos.metadata_gate_passed, FALSE) OR COALESCE(EXCLUDED.metadata_gate_passed, FALSE),
        metadata_gate_reason = COALESCE(EXCLUDED.metadata_gate_reason, yt_videos.metadata_gate_reason),
        last_fetched_at = NOW();

    IF p_queue_priority IS NOT NULL THEN
        INSERT INTO analysis_queue (
            video_id,
            priority,
            requested_by,
            source
        )
        SELECT
            p_video_id,
            p_queue_priority,
            v_requested_by,
            COALESCE(p_queue_source, p_discovery_source, 'manual')
        WHERE NOT EXISTS (
            SELECT 1
            FROM analysis_queue
            WHERE video_id = p_video_id
              AND status IN ('queued', 'processing')
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION ingest_video_cache_entry(
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    TEXT,
    INTEGER,
    TIMESTAMPTZ,
    TEXT[],
    INTEGER,
    BOOLEAN,
    BIGINT,
    BIGINT,
    BOOLEAN,
    TEXT,
    TEXT,
    BOOLEAN,
    TEXT,
    INTEGER,
    TEXT
) TO authenticated, service_role;
