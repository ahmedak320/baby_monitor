import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/supabase_client.dart';

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
  List<Map<String, dynamic>> _approvedChannels = [];
  List<Map<String, dynamic>> _blockedChannels = [];
  List<Map<String, dynamic>> _allChannels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return;

    final prefs = await SupabaseClientWrapper.client
        .from('parent_channel_prefs')
        .select('*, yt_channels(*)')
        .eq('parent_id', userId);

    final all = await SupabaseClientWrapper.client
        .from('yt_channels')
        .select()
        .order('global_trust_score', ascending: false)
        .limit(50);

    if (mounted) {
      setState(() {
        final prefsList = prefs as List;
        _approvedChannels = prefsList
            .where((p) => p['status'] == 'approved')
            .cast<Map<String, dynamic>>()
            .toList();
        _blockedChannels = prefsList
            .where((p) => p['status'] == 'blocked')
            .cast<Map<String, dynamic>>()
            .toList();
        _allChannels = (all as List).cast<Map<String, dynamic>>();
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
        title: const Text('Channels'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Approved'),
            Tab(text: 'Blocked'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChannelList(_approvedChannels, isPrefs: true),
                _buildChannelList(_blockedChannels, isPrefs: true),
                _buildChannelList(_allChannels, isPrefs: false),
              ],
            ),
    );
  }

  Widget _buildChannelList(List<Map<String, dynamic>> channels,
      {required bool isPrefs}) {
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
              backgroundColor:
                  isKids ? Colors.green : const Color(0xFF6C63FF),
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              subs > 0
                  ? '${_formatCount(subs)} subscribers${isKids ? ' · Kids channel' : ''}'
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

  Future<void> _setChannelPref(String channelId, String action) async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null || channelId.isEmpty) return;

    if (action == 'remove') {
      await SupabaseClientWrapper.client
          .from('parent_channel_prefs')
          .delete()
          .eq('parent_id', userId)
          .eq('channel_id', channelId);
    } else {
      await SupabaseClientWrapper.client.from('parent_channel_prefs').upsert(
        {
          'parent_id': userId,
          'channel_id': channelId,
          'status': action,
        },
        onConflict: 'parent_id,channel_id,applies_to_child_id',
      );
    }

    _loadChannels(); // Refresh
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}
