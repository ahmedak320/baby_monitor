import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../utils/thumbnail_preloader.dart';

/// Resolves thumbnail fallbacks before displaying a broken image state.
class ResolvedThumbnailImage extends StatefulWidget {
  final String thumbnailUrl;
  final BoxFit fit;
  final Widget placeholder;
  final Widget errorWidget;

  const ResolvedThumbnailImage({
    super.key,
    required this.thumbnailUrl,
    this.fit = BoxFit.cover,
    required this.placeholder,
    required this.errorWidget,
  });

  @override
  State<ResolvedThumbnailImage> createState() => _ResolvedThumbnailImageState();
}

class _ResolvedThumbnailImageState extends State<ResolvedThumbnailImage> {
  static const _precacheTimeout = Duration(seconds: 5);

  String? _resolvedUrl;
  bool _failed = false;
  String? _lastUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastUrl != widget.thumbnailUrl) {
      _lastUrl = widget.thumbnailUrl;
      _resolvedUrl = null;
      _failed = false;
      _resolve();
    }
  }

  @override
  void didUpdateWidget(covariant ResolvedThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thumbnailUrl != widget.thumbnailUrl) {
      _lastUrl = widget.thumbnailUrl;
      _resolvedUrl = null;
      _failed = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (widget.thumbnailUrl.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final candidates = ThumbnailPreloader.candidateUrls(widget.thumbnailUrl);
    if (candidates.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    for (final candidate in candidates) {
      try {
        await precacheImage(
          CachedNetworkImageProvider(candidate),
          context,
        ).timeout(_precacheTimeout);
        if (mounted) {
          setState(() {
            _resolvedUrl = candidate;
            _failed = false;
          });
        }
        return;
      } on TimeoutException {
        debugPrint('Thumbnail precache timed out: $candidate');
      } catch (e) {
        debugPrint('Thumbnail precache failed: $candidate ($e)');
      }
    }

    // All precache attempts failed — still try to display via CachedNetworkImage
    // which has its own retry/error handling.
    if (mounted) {
      setState(() => _resolvedUrl = candidates.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedUrl == null) {
      return _failed ? widget.errorWidget : widget.placeholder;
    }

    return CachedNetworkImage(
      imageUrl: _resolvedUrl!,
      fit: widget.fit,
      placeholder: (_, _) => widget.placeholder,
      errorWidget: (_, _, _) => widget.errorWidget,
    );
  }
}
