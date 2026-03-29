import '../datasources/remote/piped_pool.dart';
import '../datasources/remote/supabase_client.dart';
import '../models/video_metadata.dart';

/// Repository for channel search, preferences, and persistence.
class ChannelRepository {
  final PipedPool _pipedPool;

  ChannelRepository({PipedPool? pipedPool})
    : _pipedPool = pipedPool ?? PipedPool();

  /// Search channels locally in the yt_channels table.
  Future<List<ChannelMetadata>> searchLocal(String query) async {
    final escaped = _escapeLike(query);
    final rows = await SupabaseClientWrapper.client
        .from('yt_channels')
        .select()
        .ilike('title', '%$escaped%')
        .order('global_trust_score', ascending: false)
        .limit(20);

    return (rows as List)
        .map((r) => ChannelMetadata.fromSupabaseRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Search channels remotely via Piped pool (multi-instance failover),
  /// upserts results into DB.
  Future<List<ChannelMetadata>> searchRemote(String query) async {
    try {
      final channels = await _pipedPool.executeWithFailover(
        (client) => client.searchChannels(query),
      );

      // Upsert found channels into yt_channels
      for (final channel in channels) {
        await upsertChannel(channel);
      }

      return channels;
    } catch (_) {
      return [];
    }
  }

  /// Ensure a channel row exists in yt_channels (for FK dependencies).
  /// Uses ignoreDuplicates to avoid triggering RLS UPDATE restrictions.
  Future<void> ensureChannelExists(String channelId, String title) async {
    await SupabaseClientWrapper.client
        .from('yt_channels')
        .upsert(
          {
            'channel_id': channelId,
            'title': title,
            'last_fetched_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'channel_id',
          ignoreDuplicates: true,
        );
  }

  /// Upsert a channel into yt_channels.
  Future<void> upsertChannel(ChannelMetadata channel) async {
    await SupabaseClientWrapper.client
        .from('yt_channels')
        .upsert(channel.toSupabaseRow(), onConflict: 'channel_id');
  }

  /// Set parent preference for a channel (approve or block).
  /// Uses delete-then-insert when childId is null to avoid PostgreSQL
  /// NULL != NULL behavior in unique constraints.
  Future<void> setChannelPref({
    required String parentId,
    required String channelId,
    required String status,
    String? childId,
  }) async {
    if (childId == null) {
      // NULL != NULL in unique constraints, so upsert won't detect conflicts.
      // Delete any existing row first, then insert.
      await SupabaseClientWrapper.client
          .from('parent_channel_prefs')
          .delete()
          .eq('parent_id', parentId)
          .eq('channel_id', channelId)
          .isFilter('applies_to_child_id', null);
      await SupabaseClientWrapper.client.from('parent_channel_prefs').insert({
        'parent_id': parentId,
        'channel_id': channelId,
        'status': status,
      });
    } else {
      await SupabaseClientWrapper.client.from('parent_channel_prefs').upsert({
        'parent_id': parentId,
        'channel_id': channelId,
        'status': status,
        'applies_to_child_id': childId,
      }, onConflict: 'parent_id,channel_id,applies_to_child_id');
    }
  }

  /// Remove parent preference for a channel.
  Future<void> removeChannelPref({
    required String parentId,
    required String channelId,
  }) async {
    await SupabaseClientWrapper.client
        .from('parent_channel_prefs')
        .delete()
        .eq('parent_id', parentId)
        .eq('channel_id', channelId);
  }

  /// Get all channel preferences for a parent, joined with channel data.
  Future<List<Map<String, dynamic>>> getChannelPrefs(String parentId) async {
    final rows = await SupabaseClientWrapper.client
        .from('parent_channel_prefs')
        .select('*, yt_channels(*)')
        .eq('parent_id', parentId);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Get channel IDs with a specific status for a parent.
  Future<List<String>> getChannelIdsByStatus(
    String parentId,
    String status,
  ) async {
    final rows = await SupabaseClientWrapper.client
        .from('parent_channel_prefs')
        .select('channel_id')
        .eq('parent_id', parentId)
        .eq('status', status);

    return (rows as List).map((r) => r['channel_id'] as String).toList();
  }

  /// Get channel prefs as a map of channelId -> status.
  Future<Map<String, String>> getChannelPrefsMap(String parentId) async {
    final rows = await SupabaseClientWrapper.client
        .from('parent_channel_prefs')
        .select('channel_id, status')
        .eq('parent_id', parentId);

    return {
      for (final r in rows as List)
        r['channel_id'] as String: r['status'] as String,
    };
  }

  /// Escape special LIKE/ILIKE pattern characters.
  String _escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
