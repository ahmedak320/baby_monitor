import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/theme/kid_theme.dart';
import '../../../data/datasources/remote/supabase_client.dart';
import '../../../data/datasources/remote/youtube_api_client.dart';
import '../../../data/models/video_metadata.dart';
import '../../../data/datasources/remote/analysis_api.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../domain/services/metadata_gate_service.dart';
import '../../../domain/services/video_discovery_service.dart';
import '../../../providers/current_child_provider.dart';
import '../../../routing/route_names.dart';
import '../../../utils/age_calculator.dart';
import '../../../utils/duration_formatter.dart';

/// Hybrid search: shows pre-approved results first, then live YouTube
/// results that pass the metadata gate. Queues all live results for
/// full AI analysis in the background.
class KidSearchScreen extends ConsumerStatefulWidget {
  const KidSearchScreen({super.key});

  @override
  ConsumerState<KidSearchScreen> createState() => _KidSearchScreenState();
}

class _KidSearchScreenState extends ConsumerState<KidSearchScreen> {
  final _searchController = TextEditingController();
  List<VideoMetadata> _approvedResults = [];
  List<VideoMetadata> _liveResults = [];
  final Set<String> _pendingAnalysis = {};
  bool _isLoading = false;
  StreamSubscription<String>? _analysisSub;

  @override
  void initState() {
    super.initState();
    // Listen for analysis completions to promote/remove live results
    final realtimeService = ref.read(analysisRealtimeProvider);
    _analysisSub = realtimeService.onAnalysisCompleted.listen(_onAnalysisComplete);
  }

  @override
  void dispose() {
    _analysisSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onAnalysisComplete(String videoId) {
    if (!_pendingAnalysis.contains(videoId)) return;
    _pendingAnalysis.remove(videoId);

    // Check if the video was approved or rejected
    _checkAndPromote(videoId);
  }

  Future<void> _checkAndPromote(String videoId) async {
    try {
      final analysis = await VideoRepository().getAnalysis(videoId);
      if (analysis == null || !mounted) return;

      final child = ref.read(currentChildProvider);
      final childAge = child != null
          ? AgeCalculator.yearsFromDob(child.dateOfBirth)
          : 5;

      final isApproved = !analysis.isGloballyBlacklisted &&
          analysis.ageMinAppropriate <= childAge &&
          analysis.ageMaxAppropriate >= childAge;

      setState(() {
        _liveResults.removeWhere((v) => v.videoId == videoId);
        if (isApproved) {
          // Find the video metadata and move to approved
          // It might already be gone from liveResults
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _approvedResults.isNotEmpty || _liveResults.isNotEmpty;

    return Theme(
      data: KidTheme.theme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5FF),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F5FF),
          title: const Text('Search'),
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search videos...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _approvedResults = [];
                                _liveResults = [];
                                _pendingAnalysis.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _handleSearch,
                ),
              ),
              const SizedBox(height: 12),

              // Results
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : !hasResults
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'Type to search videos'
                                      : 'No results found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              // Approved results section
                              if (_approvedResults.isNotEmpty) ...[
                                _SectionHeader(
                                  icon: Icons.verified,
                                  color: Colors.green,
                                  label: 'Safe Videos',
                                ),
                                ..._approvedResults.map((video) =>
                                    _SearchResultTile(
                                      video: video,
                                      badge: _SafeBadge(),
                                      onTap: () => _playVideo(video),
                                    )),
                              ],

                              // Live results section
                              if (_liveResults.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _SectionHeader(
                                  icon: Icons.auto_awesome,
                                  color: Colors.amber,
                                  label: 'New Finds',
                                ),
                                ..._liveResults.map((video) =>
                                    _SearchResultTile(
                                      video: video,
                                      badge: _NewBadge(
                                        analyzing:
                                            _pendingAnalysis.contains(video.videoId),
                                      ),
                                      onTap: () => _playVideo(video),
                                    )),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playVideo(VideoMetadata video) {
    context.pushNamed(
      RouteNames.kidPlayer,
      pathParameters: {'videoId': video.videoId},
      queryParameters: {
        'title': video.title,
        if (video.detectedAsShort) 'isShort': 'true',
      },
    );
  }

  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final child = ref.read(currentChildProvider);
    final childAge =
        child != null ? AgeCalculator.yearsFromDob(child.dateOfBirth) : 5;

    // Run both searches in parallel
    await Future.wait([
      _searchApproved(query, childAge),
      _searchLive(query),
    ]);

    setState(() => _isLoading = false);
  }

  /// Search pre-analyzed approved content in Supabase.
  Future<void> _searchApproved(String query, int childAge) async {
    try {
      final response = await SupabaseClientWrapper.client
          .from('yt_videos')
          .select('*, video_analyses!inner(*)')
          .ilike('title', '%${query.trim()}%')
          .eq('analysis_status', 'completed')
          .lte('video_analyses.age_min_appropriate', childAge)
          .eq('video_analyses.is_globally_blacklisted', false)
          .limit(20);

      final videos = (response as List)
          .map(
              (r) => VideoMetadata.fromSupabaseRow(r as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() => _approvedResults = videos);
      }
    } catch (_) {}
  }

  /// Search live YouTube and run metadata gate on results.
  Future<void> _searchLive(String query) async {
    try {
      final ytClient = YouTubeApiClient();
      final result = await ytClient.search(query, maxResults: 10);

      final gated = <VideoMetadata>[];
      final videoRepo = VideoRepository();

      for (final video in result.videos) {
        if (video.videoId.isEmpty) continue;
        // Skip videos already in approved results
        if (_approvedResults.any((a) => a.videoId == video.videoId)) continue;

        // Run metadata gate
        final gate = MetadataGateService.check(
          title: video.title,
          channelTitle: video.channelTitle,
          description: video.description,
          durationSeconds: video.durationSeconds,
          tags: video.tags,
          categoryId: video.categoryId,
        );

        if (gate.passed) {
          gated.add(video);
          _pendingAnalysis.add(video.videoId);

          // Upsert and queue for analysis in background
          videoRepo.upsertVideo(video,
              source: 'search',
              analysisStatus: 'metadata_approved',
              metadataGatePassed: true,
              metadataGateReason: gate.reason);
          videoRepo.requestAnalysis(video.videoId,
              priority: 2, source: 'search');
        }
      }

      if (mounted) {
        setState(() => _liveResults = gated);
      }
    } catch (_) {}
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SafeBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12, color: Colors.green),
          SizedBox(width: 2),
          Text('Safe', style: TextStyle(fontSize: 10, color: Colors.green)),
        ],
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  final bool analyzing;
  const _NewBadge({this.analyzing = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (analyzing)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            const Icon(Icons.auto_awesome, size: 12, color: Colors.amber),
          const SizedBox(width: 2),
          Text(
            analyzing ? 'Checking...' : 'New',
            style: const TextStyle(fontSize: 10, color: Colors.amber),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final VideoMetadata video;
  final Widget? badge;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.video,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      video.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: video.thumbnailUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[200],
                              child:
                                  const Icon(Icons.play_circle_outline),
                            ),
                      if (video.detectedAsShort)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Short',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 9),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (badge != null) badge!,
                        if (badge != null && video.durationSeconds > 0)
                          const SizedBox(width: 8),
                        if (video.durationSeconds > 0)
                          Text(
                            DurationFormatter.videoLength(
                                video.durationSeconds),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
