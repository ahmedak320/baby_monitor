import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/theme/kid_theme.dart';
import '../../../data/datasources/remote/supabase_client.dart';
import '../../../data/models/video_metadata.dart';
import '../../../providers/current_child_provider.dart';
import '../../../routing/route_names.dart';
import '../../../utils/age_calculator.dart';
import '../../../utils/duration_formatter.dart';

/// Searches within pre-analyzed approved content only (not live YouTube).
class KidSearchScreen extends ConsumerStatefulWidget {
  const KidSearchScreen({super.key});

  @override
  ConsumerState<KidSearchScreen> createState() => _KidSearchScreenState();
}

class _KidSearchScreenState extends ConsumerState<KidSearchScreen> {
  final _searchController = TextEditingController();
  List<VideoMetadata> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                              setState(() => _results = []);
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
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'Type to search safe videos'
                                      : 'No results found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final video = _results[index];
                              return _SearchResultTile(
                                video: video,
                                onTap: () {
                                  context.pushNamed(
                                    RouteNames.kidPlayer,
                                    pathParameters: {
                                      'videoId': video.videoId,
                                    },
                                    queryParameters: {
                                      'title': video.title,
                                    },
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final child = ref.read(currentChildProvider);
      final childAge = child != null
          ? AgeCalculator.yearsFromDob(child.dateOfBirth)
          : 5;

      // Search within pre-analyzed approved content only
      final response = await SupabaseClientWrapper.client
          .from('yt_videos')
          .select('*, video_analyses!inner(*)')
          .ilike('title', '%${query.trim()}%')
          .eq('analysis_status', 'completed')
          .lte('video_analyses.age_min_appropriate', childAge)
          .eq('video_analyses.is_globally_blacklisted', false)
          .limit(20);

      final videos = (response as List)
          .map((r) => VideoMetadata.fromSupabaseRow(r as Map<String, dynamic>))
          .toList();

      setState(() {
        _results = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}

class _SearchResultTile extends StatelessWidget {
  final VideoMetadata video;
  final VoidCallback onTap;

  const _SearchResultTile({required this.video, required this.onTap});

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
                  child: video.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.play_circle_outline),
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
                    if (video.durationSeconds > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DurationFormatter.videoLength(video.durationSeconds),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
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
