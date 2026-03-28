import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/supabase_client.dart';
import '../../../data/models/video_metadata.dart';
import '../../../data/repositories/channel_repository.dart';

class ChannelManagementScreen extends ConsumerStatefulWidget {
  const ChannelManagementScreen({super.key});

  @override
  ConsumerState<ChannelManagementScreen> createState() =>
      _ChannelManagementScreenState();
}

class _ChannelManagementScreenState
    extends ConsumerState<ChannelManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _channelRepo = ChannelRepository();
  Timer? _debounce;

  List<Map<String, dynamic>> _approvedChannels = [];
  List<Map<String, dynamic>> _blockedChannels = [];
  List<Map<String, dynamic>> _allChannels = [];
  bool _isLoading = true;

  // Search state
  List<ChannelMetadata> _searchResults = [];
  Map<String, String> _prefStatuses = {}; // channelId -> status
  bool _isSearching = false;
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return;

    final prefs = await _channelRepo.getChannelPrefs(userId);

    final all = await SupabaseClientWrapper.client
        .from('yt_channels')
        .select()
        .order('global_trust_score', ascending: false)
        .limit(50);

    final prefsMap = await _channelRepo.getChannelPrefsMap(userId);

    if (mounted) {
      setState(() {
        _approvedChannels = prefs
            .where((p) => p['status'] == 'approved')
            .toList();
        _blockedChannels = prefs
            .where((p) => p['status'] == 'blocked')
            .toList();
        _allChannels = (all as List).cast<Map<String, dynamic>>();
        _prefStatuses = prefsMap;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearchActive = false;
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearchActive = true;
      _isSearching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return;

    // Search local and remote in parallel
    final results = await Future.wait([
      _channelRepo.searchLocal(query),
      _channelRepo.searchRemote(query),
    ]);

    final local = results[0];
    final remote = results[1];

    // Merge and deduplicate: local first (has richer data), then remote
    final seen = <String>{};
    final merged = <ChannelMetadata>[];
    for (final ch in [...local, ...remote]) {
      if (seen.add(ch.channelId)) {
        merged.add(ch);
      }
    }

    if (mounted) {
      setState(() {
        _searchResults = merged;
        _isSearching = false;
      });
    }
  }

  Future<void> _setChannelPref(String channelId, String action) async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null || channelId.isEmpty) return;

    if (action == 'remove') {
      await _channelRepo.removeChannelPref(
        parentId: userId,
        channelId: channelId,
      );
      setState(() => _prefStatuses.remove(channelId));
    } else {
      await _channelRepo.setChannelPref(
        parentId: userId,
        channelId: channelId,
        status: action,
      );
      setState(() => _prefStatuses[channelId] = action);
    }

    // Refresh the tab lists in the background
    _loadChannels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        bottom: _isSearchActive
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Approved'),
                  Tab(text: 'Blocked'),
                  Tab(text: 'Discover'),
                ],
              ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search channels by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Content: search results or tab views
          Expanded(
            child: _isSearchActive
                ? _buildSearchResults()
                : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChannelList(_approvedChannels, isPrefs: true),
                      _buildChannelList(_blockedChannels, isPrefs: true),
                      _buildChannelList(_allChannels, isPrefs: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No channels found',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final channel = _searchResults[index];
        final currentStatus = _prefStatuses[channel.channelId];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: channel.thumbnailUrl.isNotEmpty
                  ? NetworkImage(channel.thumbnailUrl)
                  : null,
              onBackgroundImageError: channel.thumbnailUrl.isNotEmpty
                  ? (_, _) {}
                  : null,
              backgroundColor: const Color(0xFF6C63FF),
              child: channel.thumbnailUrl.isEmpty
                  ? Text(
                      channel.title.isNotEmpty
                          ? channel.title[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              channel.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              channel.subscriberCount > 0
                  ? '${_formatCount(channel.subscriberCount)} subscribers'
                  : '',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Approve button
                IconButton(
                  icon: Icon(
                    currentStatus == 'approved'
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: currentStatus == 'approved'
                        ? Colors.green
                        : Colors.grey,
                  ),
                  tooltip: currentStatus == 'approved'
                      ? 'Remove approval'
                      : 'Approve channel',
                  onPressed: () => _setChannelPref(
                    channel.channelId,
                    currentStatus == 'approved' ? 'remove' : 'approved',
                  ),
                ),
                // Block button
                IconButton(
                  icon: Icon(
                    currentStatus == 'blocked'
                        ? Icons.block
                        : Icons.block_outlined,
                    color: currentStatus == 'blocked'
                        ? Colors.red
                        : Colors.grey,
                  ),
                  tooltip: currentStatus == 'blocked'
                      ? 'Remove block'
                      : 'Block channel',
                  onPressed: () => _setChannelPref(
                    channel.channelId,
                    currentStatus == 'blocked' ? 'remove' : 'blocked',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChannelList(
    List<Map<String, dynamic>> channels, {
    required bool isPrefs,
  }) {
    if (channels.isEmpty) {
      return Center(
        child: Text(isPrefs ? 'No channels here yet' : 'No channels found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final item = channels[index];
        final channel = isPrefs
            ? item['yt_channels'] as Map<String, dynamic>? ?? item
            : item;
        final title = channel['title'] as String? ?? 'Unknown';
        final channelId = channel['channel_id'] as String? ?? '';
        final subs = channel['subscriber_count'] as int? ?? 0;
        final isKids = channel['is_kids_channel'] as bool? ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isKids ? Colors.green : const Color(0xFF6C63FF),
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              subs > 0
                  ? '${_formatCount(subs)} subscribers${isKids ? ' \u00b7 Kids channel' : ''}'
                  : isKids
                  ? 'Kids channel'
                  : '',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _setChannelPref(channelId, action),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'approved',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Approve'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'blocked',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Block'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Remove preference'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}
