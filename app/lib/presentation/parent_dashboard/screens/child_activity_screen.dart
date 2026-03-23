import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../data/repositories/screen_time_repository.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../utils/duration_formatter.dart';

class ChildActivityScreen extends ConsumerStatefulWidget {
  final String childId;

  const ChildActivityScreen({super.key, required this.childId});

  @override
  ConsumerState<ChildActivityScreen> createState() =>
      _ChildActivityScreenState();
}

class _ChildActivityScreenState extends ConsumerState<ChildActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _videoRepo = VideoRepository();
  final _screenTimeRepo = ScreenTimeRepository();

  List<Map<String, dynamic>> _watchHistory = [];
  List<Map<String, dynamic>> _filteredLog = [];
  int _todayMinutes = 0;
  int _weekMinutes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final watch = await _videoRepo.getWatchHistory(widget.childId);
    final filtered = await _videoRepo.getFilteredLog(widget.childId);
    final todaySec = await _screenTimeRepo.getTodayUsageSeconds(widget.childId);
    final weekSec = await _screenTimeRepo.getWeekUsageSeconds(widget.childId);

    if (mounted) {
      setState(() {
        _watchHistory = watch;
        _filteredLog = filtered;
        _todayMinutes = todaySec ~/ 60;
        _weekMinutes = weekSec ~/ 60;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Watched'),
            Tab(text: 'Filtered'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats summary
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MiniStat(
                        label: 'Today',
                        value: DurationFormatter.fromSeconds(_todayMinutes * 60),
                      ),
                      _MiniStat(
                        label: 'This Week',
                        value: DurationFormatter.fromSeconds(_weekMinutes * 60),
                      ),
                      _MiniStat(
                        label: 'Videos',
                        value: '${_watchHistory.length}',
                      ),
                      _MiniStat(
                        label: 'Filtered',
                        value: '${_filteredLog.length}',
                      ),
                    ],
                  ),
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWatchList(),
                      _buildFilteredList(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWatchList() {
    if (_watchHistory.isEmpty) {
      return const Center(child: Text('No watch history yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _watchHistory.length,
      itemBuilder: (context, index) {
        final item = _watchHistory[index];
        final video = item['yt_videos'] as Map<String, dynamic>?;
        final duration = item['watch_duration_seconds'] as int? ?? 0;
        final completed = item['completed'] as bool? ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: SizedBox(
              width: 80,
              height: 45,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: video?['thumbnail_url'] != null
                    ? CachedNetworkImage(
                        imageUrl: video!['thumbnail_url'] as String,
                        fit: BoxFit.cover,
                      )
                    : Container(color: Colors.grey[200]),
              ),
            ),
            title: Text(
              video?['title'] as String? ?? 'Unknown',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              '${DurationFormatter.fromSeconds(duration)}'
              '${completed ? ' · Completed' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilteredList() {
    if (_filteredLog.isEmpty) {
      return const Center(child: Text('No filtered content yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredLog.length,
      itemBuilder: (context, index) {
        final item = _filteredLog[index];
        final video = item['yt_videos'] as Map<String, dynamic>?;
        final reason = item['filter_reason'] as String? ?? 'Unknown reason';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: SizedBox(
              width: 80,
              height: 45,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: video?['thumbnail_url'] != null
                    ? CachedNetworkImage(
                        imageUrl: video!['thumbnail_url'] as String,
                        fit: BoxFit.cover,
                      )
                    : Container(color: Colors.grey[200]),
              ),
            ),
            title: Text(
              video?['title'] as String? ?? 'Unknown',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              reason,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
            trailing: const Icon(Icons.block, color: Colors.red, size: 20),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
