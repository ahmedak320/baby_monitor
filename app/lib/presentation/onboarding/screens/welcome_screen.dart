import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/route_names.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Icon(
                Icons.child_care,
                size: 100,
                color: Color(0xFF6C63FF),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to\nBaby Monitor',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Let\'s set up safe YouTube viewing for your kids. '
                'This will only take a minute.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _FeatureRow(
                icon: Icons.shield_outlined,
                title: 'AI Content Screening',
                subtitle: 'Every video is analyzed before your child sees it',
              ),
              const SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.timer_outlined,
                title: 'Screen Time Management',
                subtitle: 'Set daily limits, breaks, and bedtimes',
              ),
              const SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.people_outlined,
                title: 'Community Filtering',
                subtitle: 'Parents help each other filter content faster',
              ),
              const Spacer(flex: 3),
              ElevatedButton(
                onPressed: () => context.pushNamed(RouteNames.addChild),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
