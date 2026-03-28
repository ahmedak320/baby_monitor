import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../utils/platform_info.dart';

/// Wraps a widget to make it focusable and visually highlighted on TV.
/// On mobile, renders the child unchanged.
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final bool autofocus;
  final FocusNode? focusNode;

  const TvFocusable({
    super.key,
    required this.child,
    this.onSelect,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      widget.onSelect?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isTV) {
      return GestureDetector(onTap: widget.onSelect, child: widget.child);
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: _isFocused ? Border.all(color: Colors.white, width: 3) : null,
        ),
        transform: _isFocused
            ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
