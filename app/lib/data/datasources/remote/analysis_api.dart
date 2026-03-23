import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Realtime subscription for new video analysis completions.
/// When the worker completes an analysis, this notifies the app
/// so newly-approved videos can appear in the kid's feed.
class AnalysisRealtimeService {
  RealtimeChannel? _channel;
  final _controller = StreamController<String>.broadcast();

  /// Stream of video IDs that have new/updated analysis results.
  Stream<String> get onAnalysisCompleted => _controller.stream;

  /// Start listening for analysis completions.
  void subscribe() {
    _channel = SupabaseClientWrapper.client
        .channel('video_analyses_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'video_analyses',
          callback: (payload) {
            final videoId = payload.newRecord['video_id'] as String?;
            if (videoId != null) {
              _controller.add(videoId);
            }
          },
        )
        .subscribe();
  }

  /// Stop listening.
  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  void dispose() {
    unsubscribe();
    _controller.close();
  }
}

/// Global realtime service provider.
final analysisRealtimeProvider = Provider<AnalysisRealtimeService>((ref) {
  final service = AnalysisRealtimeService();
  service.subscribe();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of video IDs with completed analyses.
final analysisCompletedStreamProvider = StreamProvider<String>((ref) {
  final service = ref.watch(analysisRealtimeProvider);
  return service.onAnalysisCompleted;
});
