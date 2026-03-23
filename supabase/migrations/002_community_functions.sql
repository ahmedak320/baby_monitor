-- ============================================
-- Community scoring functions
-- ============================================

-- Update channel trust scores based on their videos' analysis results.
-- Trust score = average confidence of the channel's analyzed videos.
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Increment monthly analysis usage for a user.
CREATE OR REPLACE FUNCTION increment_analysis_usage(user_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE subscriptions
    SET monthly_analyses_used = monthly_analyses_used + 1,
        updated_at = NOW()
    WHERE parent_id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reset monthly analysis counters (run monthly via cron).
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get community consensus for a video.
-- Returns the most common rating and total vote count.
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
$$ LANGUAGE plpgsql SECURITY DEFINER;
