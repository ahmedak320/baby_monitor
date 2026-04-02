// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

import 'kid_youtube_player_controller.dart';

class KidYoutubePlayer extends StatelessWidget {
  final KidYoutubePlayerController controller;
  final bool isShort;
  final String videoId;
  final ValueChanged<bool>? onPlayStateChanged;
  final VoidCallback? onEnded;
  final ValueChanged<String>? onError;

  const KidYoutubePlayer({
    super.key,
    required this.controller,
    required this.isShort,
    required this.videoId,
    this.onPlayStateChanged,
    this.onEnded,
    this.onError,
  });

  static final Set<String> _registeredViews = <String>{};

  @override
  Widget build(BuildContext context) {
    final viewType =
        'kid-youtube-player-$videoId-${isShort ? 'short' : 'video'}';
    if (_registeredViews.add(viewType)) {
      ui.platformViewRegistry.registerViewFactory(viewType, (viewId) {
        final iframe = html.IFrameElement()
          ..src = _buildEmbedUrl(videoId, isShort)
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..referrerPolicy = 'strict-origin-when-cross-origin'
          ..allow =
              'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'
          ..allowFullscreen = true;
        return iframe;
      });
    }

    return HtmlElementView(viewType: viewType);
  }

  static String _buildEmbedUrl(String videoId, bool isShort) {
    final params = <String, String>{
      'autoplay': '1',
      'playsinline': '1',
      'rel': '0',
      'modestbranding': '1',
      'enablejsapi': '1',
      'origin': Uri.base.origin,
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
}
