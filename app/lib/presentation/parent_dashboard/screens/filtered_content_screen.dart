import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/supabase_client.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../providers/current_user_provider.dart';
import '../../common/widgets/resolved_thumbnail_image.dart';

class FilteredContentScreen extends ConsumerStatefulWidget {
  const FilteredContentScreen({super.key});

  @override
  ConsumerState<FilteredContentScreen> createState() =>
      _FilteredContentScreenState();
}

class _FilteredContentScreenState extends ConsumerState<FilteredContentScreen> {
  final _videoRepo = VideoRepository();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiltered();
  }

  Future<void> _loadFiltered() async {
    final children = await ref.read(childrenProvider.future);
    final allFiltered = <Map<String, dynamic>>[];

    for (final child in children) {
      final log = await _videoRepo.getFilteredLog(child.id, limit: 30);
      for (final item in log) {
        item['child_name'] = child.name;
      }
      allFiltered.addAll(log);
    }

    if (mounted) {
      setState(() {
        _items = allFiltered;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Filtered Content')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green,
                  ),
                  SizedBox(height: 16),
                  Text('No filtered content yet'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final video = item['yt_videos'] as Map<String, dynamic>?;
                final reason = item['filter_reason'] as String? ?? 'Unknown';
                final childName = item['child_name'] as String? ?? '';
                final videoId = item['video_id'] as String? ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 100,
                                height: 56,
                                child: video?['thumbnail_url'] != null
                                    ? ResolvedThumbnailImage(
                                        thumbnailUrl:
                                            video!['thumbnail_url'] as String,
                                        fit: BoxFit.cover,
                                        placeholder: Container(
                                          color: Colors.grey[200],
                                        ),
                                        errorWidget: Container(
                                          color: Colors.grey[200],
                                        ),
                                      )
                                    : Container(color: Colors.grey[200]),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video?['title'] as String? ?? 'Unknown',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Filtered for $childName',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Rejection reason
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Override buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  _overrideVideo(videoId, 'approved'),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Allow'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  _overrideVideo(videoId, 'blocked'),
                              icon: const Icon(Icons.block, size: 16),
                              label: const Text('Keep Blocked'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _overrideVideo(String videoId, String status) async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null || videoId.isEmpty) return;

    await SupabaseClientWrapper.client.from('parent_video_overrides').upsert({
      'parent_id': userId,
      'video_id': videoId,
      'status': status,
    }, onConflict: 'parent_id,video_id,applies_to_child_id');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Video will be allowed next time'
                : 'Video will stay blocked',
          ),
        ),
      );
    }
  }
}
