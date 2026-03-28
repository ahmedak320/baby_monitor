import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/analysis_api.dart';
import '../../../domain/services/youtube_data_service.dart';
import '../../../data/models/video_metadata.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../domain/services/metadata_gate_service.dart';
import '../../../domain/services/video_discovery_service.dart';
import '../widgets/analysis_results_card.dart';

/// Debug-only screen for testing the analysis pipeline.
/// Allows direct analysis of any video by URL.
class DevAnalysisScreen extends ConsumerStatefulWidget {
  const DevAnalysisScreen({super.key});

  @override
  ConsumerState<DevAnalysisScreen> createState() => _DevAnalysisScreenState();
}

class _DevAnalysisScreenState extends ConsumerState<DevAnalysisScreen> {
  final _urlController = TextEditingController();
  VideoMetadata? _video;
  MetadataGateResult? _gateResult;
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

  Future<void> _lookup() async {
    final url = _urlController.text.trim();
    final videoId = VideoDiscoveryService.parseVideoId(url);
    if (videoId == null) {
      setState(() => _error = 'Invalid YouTube URL or video ID');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _video = null;
      _gateResult = null;
      _analysis = null;
    });

    try {
      final ytService = YouTubeDataService();
      final video = await ytService.getVideoDetails(videoId);

      final gate = MetadataGateService.check(
        title: video.title,
        channelTitle: video.channelTitle,
        description: video.description,
        durationSeconds: video.durationSeconds,
        tags: video.tags,
        categoryId: video.categoryId,
      );

      setState(() {
        _video = video;
        _gateResult = gate;
        _loading = false;
      });

      // Check existing analysis
      final analysis = await VideoRepository().getAnalysis(videoId);
      if (analysis != null && mounted) {
        setState(() => _analysis = analysis);
      }
    } catch (e) {
      setState(() {
        _error = 'Fetch failed: $e';
        _loading = false;
      });
    }
  }

  Future<void> _triggerAnalysis() async {
    if (_video == null) return;
    setState(() => _analyzing = true);

    // Upsert and queue
    final repo = VideoRepository();
    await repo.upsertVideo(_video!, source: 'dev_test');
    await repo.requestAnalysis(_video!.videoId, priority: 1, source: 'dev');

    // Listen for completion
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev: Analysis Tester'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
            ),
            child: const Text(
              'Debug tool — paste any YouTube URL to test the full '
              'analysis pipeline and view raw results.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'YouTube URL or video ID',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _lookup,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _lookup(),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          if (_loading) const LinearProgressIndicator(),

          if (_video != null) ...[
            const SizedBox(height: 16),

            // Video info
            ListTile(
              title: Text(_video!.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${_video!.channelTitle} · ${_video!.durationSeconds}s · '
                'cat:${_video!.categoryId}'
                '${_video!.detectedAsShort ? ' · SHORT' : ''}',
              ),
            ),

            // Metadata gate result
            if (_gateResult != null) ...[
              const Divider(),
              ListTile(
                leading: Icon(
                  _gateResult!.passed ? Icons.check_circle : Icons.cancel,
                  color: _gateResult!.passed ? Colors.green : Colors.red,
                ),
                title: Text(
                  'Metadata Gate: ${_gateResult!.passed ? "PASS" : "FAIL"}',
                ),
                subtitle: Text(
                  '${_gateResult!.reason}\n'
                  'Confidence: ${(_gateResult!.confidence * 100).round()}%',
                ),
              ),
            ],

            // Tags
            if (_video!.tags.isNotEmpty) ...[
              const Divider(),
              const Text('Tags',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _video!.tags
                    .map((t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Analyze button
            ElevatedButton.icon(
              onPressed: _analyzing ? null : _triggerAnalysis,
              icon: _analyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.analytics),
              label: Text(_analyzing
                  ? 'Waiting for worker...'
                  : 'Trigger Full Analysis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],

          // Analysis results
          if (_analysis != null) ...[
            const SizedBox(height: 24),
            const Text('Full Analysis Results',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            AnalysisResultsCard(analysis: _analysis!),
          ],
        ],
      ),
    );
  }
}
