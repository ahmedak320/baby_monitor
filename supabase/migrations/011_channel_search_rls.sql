-- Allow authenticated users to insert channels discovered via search
CREATE POLICY "Authenticated users can insert channels"
    ON yt_channels FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');

-- Allow authenticated users to update non-sensitive channel metadata only.
-- global_trust_score and is_kids_channel are excluded (service_role only).
CREATE POLICY "Authenticated users can update channel metadata"
    ON yt_channels FOR UPDATE
    USING (auth.role() = 'authenticated')
    WITH CHECK (
        -- Prevent users from modifying trust scores or kids-channel flag
        global_trust_score IS NOT DISTINCT FROM (SELECT global_trust_score FROM yt_channels WHERE channel_id = yt_channels.channel_id)
        AND is_kids_channel IS NOT DISTINCT FROM (SELECT is_kids_channel FROM yt_channels WHERE channel_id = yt_channels.channel_id)
    );
