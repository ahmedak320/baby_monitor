import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/supabase_client.dart';

/// Manage offline playlists (premium feature).
class OfflinePlaylistsScreen extends ConsumerStatefulWidget {
  const OfflinePlaylistsScreen({super.key});

  @override
  ConsumerState<OfflinePlaylistsScreen> createState() =>
      _OfflinePlaylistsScreenState();
}

class _OfflinePlaylistsScreenState
    extends ConsumerState<OfflinePlaylistsScreen> {
  List<Map<String, dynamic>> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return;

    final rows = await SupabaseClientWrapper.client
        .from('offline_playlists')
        .select()
        .eq('parent_id', userId)
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _playlists = (rows as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createPlaylist,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlists.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_for_offline,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No offline playlists yet',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create playlists of approved videos for offline viewing '
                          '(car rides, flights, etc.)',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _createPlaylist,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Playlist'),
                        ),
                        const SizedBox(height: 16),
                        // Curated templates
                        const Text('Or try a curated playlist:',
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Text('🚗'),
                              label: const Text('Road Trip'),
                              onPressed: () => _createFromTemplate('Road Trip'),
                            ),
                            ActionChip(
                              avatar: const Text('🌙'),
                              label: const Text('Bedtime'),
                              onPressed: () => _createFromTemplate('Bedtime'),
                            ),
                            ActionChip(
                              avatar: const Text('✈️'),
                              label: const Text('Flight'),
                              onPressed: () =>
                                  _createFromTemplate('Flight Mode'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = _playlists[index];
                    final name = playlist['name'] as String? ?? 'Unnamed';
                    final videoIds =
                        (playlist['video_ids'] as List?)?.length ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.playlist_play),
                        ),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('$videoIds videos'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'delete') {
                              _deletePlaylist(playlist['id'] as String);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _createPlaylist() async {
    final name = await _showNameDialog();
    if (name == null || name.isEmpty) return;

    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return;

    await SupabaseClientWrapper.client.from('offline_playlists').insert({
      'parent_id': userId,
      'name': name,
      'video_ids': [],
    });

    _loadPlaylists();
  }

  Future<void> _createFromTemplate(String templateName) async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return;

    await SupabaseClientWrapper.client.from('offline_playlists').insert({
      'parent_id': userId,
      'name': templateName,
      'video_ids': [], // Would be populated from curated content
    });

    _loadPlaylists();
  }

  Future<void> _deletePlaylist(String playlistId) async {
    await SupabaseClientWrapper.client
        .from('offline_playlists')
        .delete()
        .eq('id', playlistId);
    _loadPlaylists();
  }

  Future<String?> _showNameDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playlist Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g., Road Trip Mix'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}
