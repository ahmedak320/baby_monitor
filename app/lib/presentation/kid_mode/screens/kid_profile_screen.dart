import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/kid_theme.dart';
import '../../../domain/services/screen_time_service.dart';
import '../../../providers/current_child_provider.dart';
import '../../../routing/route_names.dart';
import '../widgets/parental_gate.dart';

/// "You" tab — child profile, screen time stats, exit button.
class KidProfileScreen extends ConsumerWidget {
  const KidProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentChildProvider);
    final screenTime = ref.watch(screenTimeProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),

        // Avatar
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: KidTheme.youtubeRed,
            child: Text(
              child?.name.isNotEmpty == true
                  ? child!.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            child?.name ?? 'Kid',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Screen time card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KidTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Screen Time Today',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              _ScreenTimeProgress(
                usedMinutes: screenTime.usedSecondsToday ~/ 60,
                limitMinutes: screenTime.limitSecondsToday != null
                    ? screenTime.limitSecondsToday! ~/ 60
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                screenTime.remainingMinutes != null
                    ? '${screenTime.remainingMinutes} minutes remaining'
                    : 'No limit set',
                style: TextStyle(color: KidTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Status info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KidTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.shield,
                label: 'Content Safety',
                value: 'AI-filtered',
              ),
              const Divider(color: Color(0xFF383838)),
              _InfoRow(
                icon: Icons.child_care,
                label: 'Mode',
                value: 'Kid Mode Active',
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Exit kid mode button
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _handleExit(context),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Exit Kid Mode'),
            style: OutlinedButton.styleFrom(
              foregroundColor: KidTheme.textSecondary,
              side: BorderSide(color: KidTheme.textSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleExit(BuildContext context) async {
    final passed = await showParentalGate(context);
    if (passed && context.mounted) {
      context.goNamed(RouteNames.dashboard);
    }
  }
}

class _ScreenTimeProgress extends StatelessWidget {
  final int usedMinutes;
  final int? limitMinutes;

  const _ScreenTimeProgress({required this.usedMinutes, this.limitMinutes});

  @override
  Widget build(BuildContext context) {
    final progress = limitMinutes != null && limitMinutes! > 0
        ? (usedMinutes / limitMinutes!).clamp(0.0, 1.0)
        : 0.0;

    final color = progress < 0.5
        ? Colors.green
        : progress < 0.8
        ? Colors.orange
        : Colors.red;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${usedMinutes}m used',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (limitMinutes != null)
              Text(
                '${limitMinutes}m limit',
                style: TextStyle(color: KidTheme.textSecondary, fontSize: 14),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: KidTheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: KidTheme.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: KidTheme.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
