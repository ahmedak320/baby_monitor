import 'package:flutter/material.dart';

import '../widgets/parental_gate.dart';

/// Full-screen overlay shown when daily screen time limit is reached.
/// Cannot be dismissed by the child.
class TimeUpScreen extends StatelessWidget {
  final VoidCallback onParentOverride;
  final int childAge;

  const TimeUpScreen({
    super.key,
    required this.onParentOverride,
    this.childAge = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C63FF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.nights_stay, size: 100, color: Colors.white),
                const SizedBox(height: 32),
                const Text(
                  'All done for today!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Great watching! Time to do something else.\nYou can watch more tomorrow.',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                const Icon(Icons.star, size: 60, color: Colors.amber),
                const SizedBox(height: 64),
                // Hidden parent override
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
                    style: TextStyle(color: Colors.white38, fontSize: 12),
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
