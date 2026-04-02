import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'kid_youtube_player_controller.dart';

class KidYoutubePlayer extends StatefulWidget {
  final KidYoutubePlayerController controller;
  final String videoId;
  final bool isShort;
  final ValueChanged<bool>? onPlayStateChanged;
  final VoidCallback? onEnded;
  final ValueChanged<String>? onError;

  const KidYoutubePlayer({
    super.key,
    required this.controller,
    required this.videoId,
    required this.isShort,
    this.onPlayStateChanged,
    this.onEnded,
    this.onError,
  });

  @override
  State<KidYoutubePlayer> createState() => _KidYoutubePlayerState();
}

class _KidYoutubePlayerState extends State<KidYoutubePlayer>
    implements KidYoutubePlayerBridge {
  static const _appId = 'com.babymonitor.baby_monitor';
  static const _appReferer = 'https://com.babymonitor.baby_monitor/';

  late final WebViewController _webViewController;
  bool _ready = false;
  bool _directEnded = false;
  Timer? _directProbeTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('https://www.youtube.com/') ||
                url.startsWith('https://www.youtube-nocookie.com/') ||
                url.startsWith('https://i.ytimg.com/') ||
                url.startsWith('about:blank')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            widget.onError?.call(
              error.description.isEmpty
                  ? 'This video can\'t be played right now'
                  : error.description,
            );
          },
          onPageFinished: (_) {
            _ready = true;
            // The page loaded. Cancel the screen-level startup timeout while we
            // probe the actual YouTube player state and any rendered error UI.
            widget.onPlayStateChanged?.call(true);
            widget.onPlayStateChanged?.call(false);
            _directProbeTimer?.cancel();
            _directProbeTimer = Timer.periodic(
              const Duration(milliseconds: 500),
              (_) => unawaited(_probeEmbedState()),
            );
          },
        ),
      );
    _loadPlayer();
  }

  @override
  void didUpdateWidget(covariant KidYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.isShort != widget.isShort) {
      widget.controller.attach(this);
      _loadPlayer();
    }
  }

  void _loadPlayer() {
    _ready = false;
    _directEnded = false;
    _directProbeTimer?.cancel();
    _webViewController.loadRequest(
      Uri.parse(_buildEmbedUrl(widget.videoId, widget.isShort)),
      headers: _buildEmbedHeaders(),
    );
  }

  Future<void> _probeEmbedState() async {
    if (!mounted) return;

    try {
      final raw = await _webViewController.runJavaScriptReturningResult('''
        (() => {
          const text = (document.body && document.body.innerText) || '';
          const video = document.querySelector('video');
          return JSON.stringify({
            hasVideo: !!video,
            paused: video ? video.paused : true,
            ended: video ? video.ended : false,
            currentTime: video ? video.currentTime : 0,
            text: text.slice(0, 600)
          });
        })();
      ''');

      var jsonString = raw is String ? raw : raw.toString();
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonDecode(jsonString) as String;
      }

      final payload = jsonDecode(jsonString) as Map<String, dynamic>;
      final pageText = (payload['text'] as String? ?? '').toLowerCase();
      final hasVideo = payload['hasVideo'] == true;
      final paused = payload['paused'] == true;
      final ended = payload['ended'] == true;
      final currentTime = (payload['currentTime'] as num?)?.toDouble() ?? 0;

      widget.controller.updateCurrentSeconds(currentTime);

      if (_looksLikeConfigurationError(pageText)) {
        widget.onError?.call('Video player configuration error');
        return;
      }

      if (_looksLikeEmbedRestrictedError(pageText)) {
        widget.onError?.call('This video can\'t be embedded by the channel');
        return;
      }

      if (hasVideo) {
        if (!paused) {
          widget.onPlayStateChanged?.call(true);
        } else if (currentTime > 0) {
          widget.onPlayStateChanged?.call(false);
        }

        if (ended && !_directEnded) {
          _directEnded = true;
          widget.onPlayStateChanged?.call(false);
          widget.onEnded?.call();
        }
      }
    } catch (_) {
      // Best effort probing only.
    }
  }

  bool _looksLikeConfigurationError(String text) {
    return text.contains('error 153') ||
        text.contains('error 152') ||
        text.contains('video player configuration error') ||
        text.contains('missing referer');
  }

  bool _looksLikeEmbedRestrictedError(String text) {
    return text.contains('playback on other websites has been disabled') ||
        text.contains('owner has restricted playback') ||
        text.contains('embedding disabled') ||
        text.contains('watch on youtube');
  }

  @override
  Future<void> pause() async {
    if (!_ready) return;
    await _webViewController.runJavaScript('''
      (() => {
        const video = document.querySelector('video');
        if (video) video.pause();
      })();
    ''');
  }

  @override
  Future<void> play() async {
    if (!_ready) return;
    await _webViewController.runJavaScript('''
      (() => {
        const video = document.querySelector('video');
        const playButton = document.querySelector('.ytp-large-play-button');
        if (playButton) {
          playButton.click();
          return;
        }
        if (video && video.play) video.play();
      })();
    ''');
  }

  @override
  Future<void> seekTo(double seconds) async {
    if (!_ready) return;
    await _webViewController.runJavaScript('''
      (() => {
        const video = document.querySelector('video');
        if (video) video.currentTime = ${seconds.toStringAsFixed(3)};
      })();
    ''');
  }

  @override
  void dispose() {
    _directProbeTimer?.cancel();
    widget.controller.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _webViewController);
  }
}

String _buildEmbedUrl(String videoId, bool isShort) {
  final params = <String, String>{
    'autoplay': '1',
    'playsinline': '1',
    'rel': '0',
    'modestbranding': '1',
    'enablejsapi': '1',
    'origin': _KidYoutubePlayerState._appReferer,
    'widget_referrer': _KidYoutubePlayerState._appReferer,
    'controls': isShort ? '0' : '1',
    'fs': isShort ? '0' : '1',
  };
  final query = params.entries
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');
  return 'https://www.youtube.com/embed/$videoId?$query';
}

Map<String, String> _buildEmbedHeaders() {
  return const {
    'Referer': _KidYoutubePlayerState._appReferer,
    'X-Requested-With': _KidYoutubePlayerState._appId,
  };
}
