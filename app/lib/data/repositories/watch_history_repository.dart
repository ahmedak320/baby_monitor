import '../datasources/remote/supabase_client.dart';
import '../models/video_metadata.dart';

/// Repository for accessing a child's watch history.
class WatchHistoryRepository {
  final _client = SupabaseClientWrapper.client;

  /// Get watch history for a child, most recent first.
  Future<List<WatchHistoryEntry>> getHistory({
    required String childId,
    int limit = 50,
  }) async {
    final rows = await _client
        .from('watch_history')
        .select('*, yt_videos(*)')
        .eq('child_id', childId)
        .order('watched_at', ascending: false)
        .limit(limit);

    return rows.map((row) {
      final videoRow = row['yt_videos'] as Map<String, dynamic>?;
      return WatchHistoryEntry(
        id: row['id'] as String,
        childId: row['child_id'] as String,
        videoId: row['video_id'] as String,
        watchedAt: DateTime.parse(row['watched_at'] as String),
        durationWatched: row['duration_watched'] as int? ?? 0,
        video: videoRow != null
            ? VideoMetadata.fromSupabaseRow(videoRow)
            : null,
      );
    }).toList();
  }
}

/// A single watch history entry.
class WatchHistoryEntry {
  final String id;
  final String childId;
  final String videoId;
  final DateTime watchedAt;
  final int durationWatched;
  final VideoMetadata? video;

  const WatchHistoryEntry({
    required this.id,
    required this.childId,
    required this.videoId,
    required this.watchedAt,
    this.durationWatched = 0,
    this.video,
  });
}
