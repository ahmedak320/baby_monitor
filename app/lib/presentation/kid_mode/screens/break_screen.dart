import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/services/screen_time_service.dart';

/// Full-screen overlay shown during mandatory breaks.
class BreakScreen extends ConsumerStatefulWidget {
  final int breakDurationSeconds;

  const BreakScreen({super.key, required this.breakDurationSeconds});

  @override
  ConsumerState<BreakScreen> createState() => _BreakScreenState();
}

class _BreakScreenState extends ConsumerState<BreakScreen> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.breakDurationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _timer?.cancel();
          ref.read(screenTimeProvider.notifier).breakCompleted();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;

    return Scaffold(
      backgroundColor: const Color(0xFF4ECDC4),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.self_improvement,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Time for a break!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Stand up, stretch, and move around.',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Countdown
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$minutes:${seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _remaining > 0
                      ? 'Back in ${minutes > 0 ? '$minutes min ' : ''}${seconds}s'
                      : 'Break over! Resuming...',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
