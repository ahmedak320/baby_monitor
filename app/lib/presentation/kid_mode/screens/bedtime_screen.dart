import 'package:flutter/material.dart';

import '../widgets/parental_gate.dart';

/// Full-screen overlay shown during bedtime hours.
class BedtimeScreen extends StatelessWidget {
  final VoidCallback onParentOverride;
  final int childAge;

  const BedtimeScreen({
    super.key,
    required this.onParentOverride,
    this.childAge = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🌙', style: TextStyle(fontSize: 80)),
                const SizedBox(height: 32),
                const Text(
                  'Time for bed!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sweet dreams! Videos will be here\nwhen you wake up.',
                  style: TextStyle(fontSize: 18, color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                const Text('⭐ ⭐ ⭐', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 64),
                TextButton(
                  onPressed: () async {
                    final passed = await showParentalGate(
                      context,
                      childAge: childAge,
                    );
                    if (passed) onParentOverride();
                  },
                  child: const Text(
                    'Parent? Tap here',
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
