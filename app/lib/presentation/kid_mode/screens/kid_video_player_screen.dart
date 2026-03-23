import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../data/repositories/video_repository.dart';
import '../../../providers/current_child_provider.dart';

class KidVideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoId;
  final String? videoTitle;

  const KidVideoPlayerScreen({
    super.key,
    required this.videoId,
    this.videoTitle,
  });

  @override
  ConsumerState<KidVideoPlayerScreen> createState() =>
      _KidVideoPlayerScreenState();
}

class _KidVideoPlayerScreenState extends ConsumerState<KidVideoPlayerScreen> {
  late YoutubePlayerController _controller;
  final _videoRepo = VideoRepository();
  Timer? _watchTimer;
  int _watchedSeconds = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false, // parents can configure this
        enableCaption: true,
        hideControls: false,
        hideThumbnail: true,
        loop: false,
        controlsVisibleAtStart: false,
      ),
    )..addListener(_onPlayerStateChange);

    // Start watch time tracking
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPlaying) {
        _watchedSeconds++;
      }
    });
  }

  void _onPlayerStateChange() {
    if (!mounted) return;
    final state = _controller.value.playerState;
    setState(() {
      _isPlaying = state == PlayerState.playing;
    });

    if (state == PlayerState.ended) {
      _saveWatchRecord(completed: true);
    }
  }

  @override
  void deactivate() {
    // Save watch record when leaving the screen
    _saveWatchRecord(completed: false);
    super.deactivate();
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    _controller.dispose();
    // Restore system UI
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _saveWatchRecord({required bool completed}) async {
    final child = ref.read(currentChildProvider);
    if (child == null || _watchedSeconds < 5) return; // Don't record < 5s

    try {
      await _videoRepo.recordWatch(
        childId: child.id,
        videoId: widget.videoId,
        durationSeconds: _watchedSeconds,
        completed: completed,
      );
    } catch (_) {
      // Silently fail - watch tracking is non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Video player
            Expanded(
              child: YoutubePlayerBuilder(
                player: YoutubePlayer(
                  controller: _controller,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: const Color(0xFF6C63FF),
                  progressColors: const ProgressBarColors(
                    playedColor: Color(0xFF6C63FF),
                    handleColor: Color(0xFF6C63FF),
                  ),
                  onEnded: (_) => _onVideoEnded(),
                ),
                builder: (context, player) {
                  return Column(
                    children: [
                      // Minimal top bar with back button
                      _TopBar(
                        title: widget.videoTitle ?? '',
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      // Player fills remaining space
                      Expanded(child: player),
                      // Bottom info bar
                      _BottomBar(
                        watchedSeconds: _watchedSeconds,
                        isPlaying: _isPlaying,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onVideoEnded() {
    _saveWatchRecord(completed: true);
    // TODO: Show "Up Next" overlay with pre-approved suggestions
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int watchedSeconds;
  final bool isPlaying;

  const _BottomBar({
    required this.watchedSeconds,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = watchedSeconds ~/ 60;
    final seconds = watchedSeconds % 60;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            isPlaying ? Icons.play_arrow : Icons.pause,
            color: Colors.white54,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '${minutes}m ${seconds.toString().padLeft(2, '0')}s watched',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
