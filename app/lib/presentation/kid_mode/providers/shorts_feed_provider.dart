import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/video_repository.dart';
import '../../../domain/services/content_filter_service.dart';
import '../../../domain/services/feed_curation_service.dart';
import '../../../providers/current_child_provider.dart';
import '../../../utils/age_calculator.dart';

/// Provides pre-filtered Shorts for the vertical swipe feed.
final shortsFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final child = ref.watch(currentChildProvider);
  if (child == null) return [];

  final videoRepo = VideoRepository();
  final filterService = ContentFilterService();
  final childAge = AgeCalculator.yearsFromDob(child.dateOfBirth);

  try {
    // Fetch videos, preferring shorts
    final videos = await videoRepo.getApprovedVideos(
      childId: child.id,
      childAge: childAge,
      limit: 100,
      includeMetadataApproved: false,
    );

    // Filter for shorts only
    final shorts = videos.where((v) => v.detectedAsShort).toList();

    final feedItems = <FeedItem>[];
    for (final video in shorts) {
      if (feedItems.length >= 50) break;

      final analysis = await videoRepo.getAnalysis(video.videoId);
      if (analysis != null) {
        final result = filterService.filterForChild(
          analysis: analysis,
          child: child,
        );
        if (!result.isApproved) continue;
      } else if (video.analysisStatus != 'metadata_approved') {
        continue;
      }

      feedItems.add(FeedItem(
        video: video,
        analysis: analysis,
        contentLabels: analysis?.contentLabels ?? [],
      ));
    }

    return feedItems;
  } catch (e) {
    debugPrint('Shorts feed error: $e');
    return [];
  }
});
