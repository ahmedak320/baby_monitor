import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Global D-pad key handler for TV navigation.
/// Wraps a child widget to intercept D-pad Back button for navigation.
class DpadHandler extends StatefulWidget {
  final Widget child;

  const DpadHandler({super.key, required this.child});

  @override
  State<DpadHandler> createState() => _DpadHandlerState();
}

class _DpadHandlerState extends State<DpadHandler> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;

        if (event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.browserBack ||
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      },
      child: widget.child,
    );
  }
}

/// Maps media remote keys to video player actions.
class TvMediaKeyHandler {
  /// Returns the media action for a key event, or null if not a media key.
  static TvMediaAction? fromKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return null;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter) {
      return TvMediaAction.playPause;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      return TvMediaAction.seekBack;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      return TvMediaAction.seekForward;
    }
    return null;
  }
}

enum TvMediaAction { playPause, seekBack, seekForward }
