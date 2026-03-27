// Supabase Edge Function: aggregate-ratings
// Aggregates community ratings and adjusts analysis confidence scores.
//
// Called periodically (cron) or after a batch of new ratings.
// Analyses with many "accurate" votes get higher confidence.
// Analyses with "too_strict" or "too_lenient" votes trigger re-analysis.
// Analyses with "dangerous" votes get globally blacklisted.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DANGEROUS_THRESHOLD = 2; // 2+ dangerous reports = auto-blacklist
const CONFIDENCE_BOOST_PER_ACCURATE = 0.02;
const CONFIDENCE_PENALTY_PER_DISAGREEMENT = 0.05;
const MAX_CONFIDENCE = 0.98;
const MIN_CONFIDENCE = 0.1;

const CORS_HEADERS = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
};

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  try {
    // Authenticate request
    const functionSecret = Deno.env.get("FUNCTION_SECRET") ?? "";
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!functionSecret || authHeader !== `Bearer ${functionSecret}`) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: CORS_HEADERS }
      );
    }
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Get all video IDs that have community ratings
    const { data: ratedVideos, error: ratedError } = await supabase
      .from("community_ratings")
      .select("video_id")
      .order("created_at", { ascending: false })
      .limit(500);

    if (ratedError) throw ratedError;

    // Deduplicate video IDs
    const videoIds = [...new Set(ratedVideos?.map((r: any) => r.video_id) ?? [])];

    let updated = 0;
    let blacklisted = 0;

    for (const videoId of videoIds) {
      // Get all ratings for this video
      const { data: ratings, error: ratingsError } = await supabase
        .from("community_ratings")
        .select("rating")
        .eq("video_id", videoId);

      if (ratingsError || !ratings) continue;

      const counts = {
        accurate: 0,
        too_strict: 0,
        too_lenient: 0,
        dangerous: 0,
      };

      for (const r of ratings) {
        const rating = r.rating as keyof typeof counts;
        if (rating in counts) counts[rating]++;
      }

      // Get current analysis
      const { data: analysis, error: analysisError } = await supabase
        .from("video_analyses")
        .select("confidence, is_globally_blacklisted")
        .eq("video_id", videoId)
        .single();

      if (analysisError || !analysis) continue;

      let newConfidence = analysis.confidence ?? 0.5;
      let shouldBlacklist = analysis.is_globally_blacklisted ?? false;

      // Boost confidence for accurate ratings
      newConfidence += counts.accurate * CONFIDENCE_BOOST_PER_ACCURATE;

      // Penalize for disagreements
      newConfidence -= (counts.too_strict + counts.too_lenient) * CONFIDENCE_PENALTY_PER_DISAGREEMENT;

      // Clamp
      newConfidence = Math.max(MIN_CONFIDENCE, Math.min(MAX_CONFIDENCE, newConfidence));

      // Auto-blacklist if enough dangerous reports
      if (counts.dangerous >= DANGEROUS_THRESHOLD) {
        shouldBlacklist = true;
        blacklisted++;
      }

      // Update analysis
      const { error: updateError } = await supabase
        .from("video_analyses")
        .update({
          confidence: newConfidence,
          is_globally_blacklisted: shouldBlacklist,
          ...(shouldBlacklist && !analysis.is_globally_blacklisted
            ? { blacklist_reason: `Community reported dangerous (${counts.dangerous} reports)` }
            : {}),
        })
        .eq("video_id", videoId);

      if (!updateError) updated++;
    }

    // Also update channel trust scores based on their videos' analyses
    const { error: channelError } = await supabase.rpc(
      "update_channel_trust_scores"
    );

    return new Response(
      JSON.stringify({
        success: true,
        videos_processed: videoIds.length,
        analyses_updated: updated,
        newly_blacklisted: blacklisted,
        channel_trust_updated: !channelError,
      }),
      { headers: CORS_HEADERS }
    );
  } catch (error) {
    console.error("aggregate-ratings error:", (error as Error).message);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: CORS_HEADERS }
    );
  }
});
