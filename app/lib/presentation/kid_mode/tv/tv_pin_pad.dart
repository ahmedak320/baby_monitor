import 'package:flutter/material.dart';

import '../../../config/theme/kid_theme.dart';
import 'tv_focusable.dart';

/// D-pad-friendly numeric PIN pad for TV.
class TvPinPad extends StatefulWidget {
  final int pinLength;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onCancel;
  final String? title;

  const TvPinPad({
    super.key,
    this.pinLength = 4,
    required this.onSubmit,
    this.onCancel,
    this.title,
  });

  @override
  State<TvPinPad> createState() => _TvPinPadState();
}

class _TvPinPadState extends State<TvPinPad> {
  String _enteredPin = '';

  void _addDigit(String digit) {
    if (_enteredPin.length >= widget.pinLength) return;
    setState(() => _enteredPin += digit);
    if (_enteredPin.length == widget.pinLength) {
      widget.onSubmit(_enteredPin);
    }
  }

  void _backspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _clear() {
    setState(() => _enteredPin = '');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: KidTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.pinLength, (i) {
            final filled = i < _enteredPin.length;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? KidTheme.youtubeRed : Colors.transparent,
                  border: Border.all(
                    color: filled
                        ? KidTheme.youtubeRed
                        : KidTheme.textSecondary,
                    width: 2,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),

        // Number grid: 3x4
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _buildRow(['1', '2', '3']),
              const SizedBox(height: 12),
              _buildRow(['4', '5', '6']),
              const SizedBox(height: 12),
              _buildRow(['7', '8', '9']),
              const SizedBox(height: 12),
              _buildRow(['C', '0', '\u232b']), // Clear, 0, Backspace
            ],
          ),
        ),

        if (widget.onCancel != null) ...[
          const SizedBox(height: 24),
          TvFocusable(
            onSelect: widget.onCancel,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: KidTheme.surfaceVariant,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, color: KidTheme.textSecondary),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: TvFocusable(
            autofocus: key == '5', // center of pad gets initial focus
            onSelect: () {
              if (key == 'C') {
                _clear();
              } else if (key == '\u232b') {
                _backspace();
              } else {
                _addDigit(key);
              }
            },
            child: Container(
              width: 72,
              height: 56,
              decoration: BoxDecoration(
                color: KidTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                key,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: KidTheme.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
