import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../data/datasources/remote/analysis_api.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../providers/current_child_provider.dart';
import '../../../utils/platform_info.dart';
import '../tv/dpad_handler.dart';

class KidVideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoId;
  final String? videoTitle;
  final bool isShort;

  const KidVideoPlayerScreen({
    super.key,
    required this.videoId,
    this.videoTitle,
    this.isShort = false,
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
  bool _isInterrupted = false;
  String? _interruptReason;
  bool _hasError = false;
  String? _errorMessage;
  Timer? _errorTimer;
  StreamSubscription<String>? _analysisSub;
  StreamSubscription<YoutubePlayerValue>? _playerStateSub;
  StreamSubscription<YoutubeVideoState>? _videoStateSub;

  @override
  void initState() {
    super.initState();

    // Shorts: lock to portrait (mobile only — TV is always landscape)
    if (widget.isShort && !PlatformInfo.isTV) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: YoutubePlayerParams(
        mute: false,
        showControls: !widget.isShort,
        showFullscreenButton: !widget.isShort,
        loop: false,
        enableCaption: true,
        playsInline: true,
      ),
    );

    _playerStateSub = _controller.listen((event) {
      _onPlayerStateChange(event);
    });

    // Track playing state via videoStateStream (fires every 100ms while playing)
    _videoStateSub = _controller.videoStateStream.listen((state) {
      if (!mounted) return;
      if (!_isPlaying) {
        _errorTimer?.cancel();
        setState(() => _isPlaying = true);
      }
    });

    // Fallback error detection: if player doesn't start within 8 seconds
    _errorTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_isPlaying && !_isInterrupted && !_hasError) {
        _showError('This video is unavailable');
      }
    });

    // Autoplay is on, so assume playing after a short delay.
    // Stream events update _isPlaying when available (native platforms),
    // but on web postMessage may be blocked by cross-origin restrictions.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isPlaying && !_isInterrupted && !_hasError) {
        _errorTimer?.cancel();
        setState(() => _isPlaying = true);
      }
    });

    // Watch time tracking
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPlaying) {
        setState(() => _watchedSeconds++);
      }
    });

    // Subscribe to analysis completions for real-time interruption
    _startAnalysisListener();
  }

  void _startAnalysisListener() {
    final realtimeService = ref.read(analysisRealtimeProvider);
    _analysisSub =
        realtimeService.onAnalysisCompleted.listen(_onAnalysisComplete);
  }

  Future<void> _onAnalysisComplete(String videoId) async {
    if (videoId != widget.videoId || _isInterrupted) return;

    // Check if the analysis rejected this video
    final analysis = await _videoRepo.getAnalysis(videoId);
    if (analysis == null || !mounted) return;

    final child = ref.read(currentChildProvider);
    if (child == null) return;

    // Check if video passes content filter
    final isRejected = analysis.isGloballyBlacklisted ||
        analysis.violenceScore > 4.0 ||
        analysis.audioSafetyScore < 4.0 ||
        analysis.scarinessScore > 7.0;

    if (isRejected) {
      _interruptVideo('Content flagged by safety analysis');
    }
  }

  void _interruptVideo(String reason) {
    if (_isInterrupted || !mounted) return;

    setState(() {
      _isInterrupted = true;
      _interruptReason = reason;
    });

    // Pause the player
    _controller.pauseVideo();

    // Log the interruption
    final child = ref.read(currentChildProvider);
    if (child != null) {
      _videoRepo.logInterruption(
        childId: child.id,
        videoId: widget.videoId,
        reason: reason,
        watchedSeconds: _watchedSeconds,
      );
    }

    // Auto-navigate to next video after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _showError(String message) {
    if (_hasError || !mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
    _controller.pauseVideo();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _onPlayerStateChange(YoutubePlayerValue value) {
    if (!mounted) return;

    // Detect YouTube embed errors (e.g., 150/152 = not embeddable)
    if (value.hasError) {
      _showError("This video can't be played right now");
      return;
    }

    final playing = value.playerState == PlayerState.playing;
    if (_isPlaying != playing) {
      if (playing) _errorTimer?.cancel();
      setState(() => _isPlaying = playing);
    }

    if (value.playerState == PlayerState.ended) {
      _saveWatchRecord(completed: true);
      _onVideoEnded();
    }
  }

  @override
  void deactivate() {
    if (!_isInterrupted) {
      _saveWatchRecord(completed: false);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _analysisSub?.cancel();
    _playerStateSub?.cancel();
    _videoStateSub?.cancel();
    _watchTimer?.cancel();
    _errorTimer?.cancel();
    _controller.close();
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _saveWatchRecord({required bool completed}) async {
    final child = ref.read(currentChildProvider);
    if (child == null || _watchedSeconds < 5) return;

    try {
      await _videoRepo.recordWatch(
        childId: child.id,
        videoId: widget.videoId,
        durationSeconds: _watchedSeconds,
        completed: completed,
      );
    } catch (_) {}
  }

  KeyEventResult _handleTvKey(FocusNode node, KeyEvent event) {
    if (!PlatformInfo.isTV || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final action = TvMediaKeyHandler.fromKeyEvent(event);
    if (action == null) return KeyEventResult.ignored;

    switch (action) {
      case TvMediaAction.playPause:
        if (_isPlaying) {
          _controller.pauseVideo();
        } else {
          _controller.playVideo();
        }
        return KeyEventResult.handled;
      case TvMediaAction.seekBack:
        _controller.currentTime.then((t) {
          _controller.seekTo(seconds: (t - 10).clamp(0, double.infinity));
        });
        return KeyEventResult.handled;
      case TvMediaAction.seekForward:
        _controller.currentTime.then((t) {
          _controller.seekTo(seconds: t + 10);
        });
        return KeyEventResult.handled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Focus(
          autofocus: PlatformInfo.isTV,
          onKeyEvent: _handleTvKey,
          child: Stack(
          children: [
            // Main player
            Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      if (!widget.isShort)
                        _TopBar(
                          title: widget.videoTitle ?? '',
                          onBack: () => Navigator.of(context).pop(),
                        ),
                      Expanded(
                        child: YoutubePlayer(
                          controller: _controller,
                          aspectRatio: widget.isShort ? 9 / 16 : 16 / 9,
                          backgroundColor: Colors.black,
                        ),
                      ),
                      if (!widget.isShort)
                        _BottomBar(
                          watchedSeconds: _watchedSeconds,
                          isPlaying: _isPlaying,
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Interruption overlay
            if (_isInterrupted)
              _InterruptionOverlay(reason: _interruptReason ?? ''),

            // Error overlay
            if (_hasError)
              _ErrorOverlay(message: _errorMessage ?? 'Video unavailable'),

            // Shorts: back button overlay
            if (widget.isShort)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  void _onVideoEnded() {
    _saveWatchRecord(completed: true);
    // Navigate back — feed will show next video
    if (mounted) Navigator.of(context).pop();
  }
}

/// Child-friendly interruption overlay shown when analysis rejects a video.
class _InterruptionOverlay extends StatelessWidget {
  final String reason;

  const _InterruptionOverlay({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF6C63FF).withValues(alpha: 0.95),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🎬',
              style: TextStyle(fontSize: 64),
            ),
            SizedBox(height: 16),
            Text(
              'Time for a new video!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Finding something fun...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kid-friendly error overlay shown when a video can't be played.
class _ErrorOverlay extends StatelessWidget {
  final String message;
  const _ErrorOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Going back...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
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
