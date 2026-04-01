import 'dart:html';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

class KidYoutubePlayer extends StatelessWidget {
  final Object? controller;
  final bool isShort;
  final String videoId;

  const KidYoutubePlayer({
    super.key,
    required this.controller,
    required this.isShort,
    required this.videoId,
  });

  static final Set<String> _registeredViews = <String>{};

  @override
  Widget build(BuildContext context) {
    final viewType =
        'kid-youtube-player-${videoId}-${isShort ? 'short' : 'video'}';
    if (_registeredViews.add(viewType)) {
      ui.platformViewRegistry.registerViewFactory(viewType, (viewId) {
        final iframe = IFrameElement()
          ..src = _buildEmbedUrl(videoId, isShort)
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
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
