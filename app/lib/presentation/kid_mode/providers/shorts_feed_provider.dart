import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/channel_repository.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../domain/services/content_filter_service.dart';
import '../../../domain/services/feed_curation_service.dart';
import '../../../providers/current_child_provider.dart';
import '../../../utils/age_calculator.dart';
import 'kid_feed_provider.dart';

/// Provides pre-filtered Shorts for the vertical swipe feed.
final shortsFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final child = ref.watch(currentChildProvider);
  // Rebuild when analysis completes (reactive filtering)
  ref.watch(analysisRefreshCounterProvider);
  if (child == null) return [];

  final videoRepo = VideoRepository();
  final filterService = ContentFilterService();
  final channelRepo = ChannelRepository();
  final discovery = ref.read(videoDiscoveryProvider);
  final childAge = AgeCalculator.yearsFromDob(child.dateOfBirth);

  try {
    // Fetch videos, preferring shorts
    final videos = await videoRepo.getApprovedVideos(
      childId: child.id,
      childAge: childAge,
      limit: 120,
      includeMetadataApproved: true,
      includePending: true, // Include pending shorts for immediate display
    );

    var shorts = videos.where((v) => v.detectedAsShort).toList();

    if (shorts.isEmpty) {
      // discoverShorts() returns enriched, short-filtered videos that have
      // been ingested into the database.  Use them directly as candidates
      // because they won't yet satisfy getApprovedVideos() criteria (no
      // analysis row / channel trust score).
      final discovered = await discovery.discoverShorts();
      if (discovered.isNotEmpty) {
        shorts = discovered.where((v) => v.detectedAsShort).toList();
      }
    }

    final channelPrefs = await channelRepo.getChannelPrefsMap(child.parentId);

    final feedItems = <FeedItem>[];
    for (final video in shorts) {
      if (feedItems.length >= 50) break;

      final analysis = await videoRepo.getAnalysis(video.videoId);
      if (analysis != null) {
        final result = filterService.filterForChild(
          analysis: analysis,
          child: child,
          channelId: video.channelId,
          channelPrefs: channelPrefs,
        );
        if (!result.isApproved) {
          videoRepo.logFiltered(
            childId: child.id,
            videoId: video.videoId,
            reason: result.reason,
          );
          continue;
        }
        // Analysis exists and video is approved - add to feed
        feedItems.add(
          FeedItem(
            video: video,
            analysis: analysis,
            contentLabels: analysis.contentLabels,
            isPendingAnalysis: false,
          ),
        );
      } else {
        // No analysis yet — show the video (whitelist-until-checked)
        feedItems.add(
          FeedItem(
            video: video,
            analysis: null,
            contentLabels: [],
            isPendingAnalysis: true,
          ),
        );
      }
    }

    return feedItems;
  } catch (e) {
    debugPrint('Shorts feed error: $e');
    return [];
  }
});
