import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../data/datasources/remote/analysis_api.dart';
import '../../../data/datasources/remote/youtube_api_client.dart';
import '../../../data/models/video_metadata.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../domain/services/video_discovery_service.dart';
import '../widgets/analysis_results_card.dart';

class LinkSubmissionScreen extends ConsumerStatefulWidget {
  const LinkSubmissionScreen({super.key});

  @override
  ConsumerState<LinkSubmissionScreen> createState() =>
      _LinkSubmissionScreenState();
}

class _LinkSubmissionScreenState extends ConsumerState<LinkSubmissionScreen> {
  final _urlController = TextEditingController();
  VideoMetadata? _video;
  VideoAnalysis? _analysis;
  bool _loading = false;
  bool _analyzing = false;
  String? _error;
  StreamSubscription<String>? _analysisSub;

  @override
  void dispose() {
    _analysisSub?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _lookupVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final videoId = VideoDiscoveryService.parseVideoId(url);
    if (videoId == null) {
      setState(() => _error = 'Invalid YouTube URL');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _video = null;
      _analysis = null;
    });

    try {
      final ytClient = YouTubeApiClient();
      final video = await ytClient.getVideoDetails(videoId);
      setState(() {
        _video = video;
        _loading = false;
      });

      // Check if analysis already exists
      final analysis = await VideoRepository().getAnalysis(videoId);
      if (analysis != null && mounted) {
        setState(() => _analysis = analysis);
      }
    } catch (e) {
      setState(() {
        _error = 'Could not fetch video. Please check the URL and try again.';
        _loading = false;
      });
    }
  }

  Future<void> _analyze() async {
    if (_video == null) return;

    setState(() => _analyzing = true);

    final discovery = VideoDiscoveryService();
    await discovery.submitParentLink(
      videoUrl: _urlController.text.trim(),
      action: 'analyze',
    );

    // Listen for analysis completion
    final realtimeService = ref.read(analysisRealtimeProvider);
    _analysisSub = realtimeService.onAnalysisCompleted.listen((videoId) async {
      if (videoId != _video!.videoId) return;

      final analysis = await VideoRepository().getAnalysis(videoId);
      if (analysis != null && mounted) {
        setState(() {
          _analysis = analysis;
          _analyzing = false;
        });
        _analysisSub?.cancel();
      }
    });
  }

  Future<void> _approve() async {
    if (_video == null) return;
    final discovery = VideoDiscoveryService();
    await discovery.submitParentLink(
      videoUrl: _urlController.text.trim(),
      action: 'approve',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video approved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _block() async {
    if (_video == null) return;
    final discovery = VideoDiscoveryService();
    await discovery.submitParentLink(
      videoUrl: _urlController.text.trim(),
      action: 'block',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video blocked'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Video Link')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Paste a YouTube URL to analyze, approve, or block.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          // URL input
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'https://youtube.com/watch?v=...',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _lookupVideo,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _lookupVideo(),
          ),
          const SizedBox(height: 8),

          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),

          // Video preview
          if (_video != null) ...[
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_video!.thumbnailUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: _video!.thumbnailUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _video!.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _video!.channelTitle,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (_video!.durationSeconds > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_video!.durationSeconds ~/ 60}m ${_video!.durationSeconds % 60}s'
                            '${_video!.detectedAsShort ? ' (Short)' : ''}',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _analyzing ? null : _analyze,
                    icon: _analyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics),
                    label: Text(_analyzing ? 'Analyzing...' : 'Analyze'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _approve,
                    icon: const Icon(Icons.check, color: Colors.green),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _block,
                    icon: const Icon(Icons.block, color: Colors.red),
                    label: const Text('Block'),
                  ),
                ),
              ],
            ),
          ],

          // Analysis results
          if (_analysis != null) ...[
            const SizedBox(height: 24),
            const Text(
              'Analysis Results',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            AnalysisResultsCard(analysis: _analysis!),
          ],
        ],
      ),
    );
  }
}
