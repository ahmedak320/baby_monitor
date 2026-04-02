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
  String? _resolvedUrl;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ResolvedThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thumbnailUrl != widget.thumbnailUrl) {
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

    for (final candidate in ThumbnailPreloader.candidateUrls(
      widget.thumbnailUrl,
    )) {
      try {
        await precacheImage(CachedNetworkImageProvider(candidate), context);
        if (mounted) {
          setState(() {
            _resolvedUrl = candidate;
            _failed = false;
          });
        }
        return;
      } catch (_) {
        // Try the next fallback before surfacing an error state.
      }
    }

    if (mounted) {
      setState(() => _failed = true);
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
