import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/services/age_transition_service.dart';
import '../../../presentation/auth/providers/auth_provider.dart';
import '../../../providers/subscription_provider.dart';
import '../../../routing/route_names.dart';
import '../../../utils/age_calculator.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/age_transition_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _checkedTransitions = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedTransitions) {
      _checkedTransitions = true;
      _checkAgeTransitions();
    }
  }

  Future<void> _checkAgeTransitions() async {
    final stats = await ref.read(dashboardStatsProvider.future);
    if (!mounted || stats.isEmpty) return;

    final children = stats.map((s) => s.child).toList();
    final transitions = await AgeTransitionService.checkTransitions(children);

    if (!mounted || transitions.isEmpty) return;

    // Show dialog for each transition
    for (final transition in transitions) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AgeTransitionDialog(
          transition: transition,
          onApplyDefaults: () {
            AgeTransitionService.applyTransitionSettings(
              transition,
              ProfileRepository(),
            );
            Navigator.of(ctx).pop();
            ref.invalidate(dashboardStatsProvider);
          },
          onKeepCurrent: () => Navigator.of(ctx).pop(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final subscriptionAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Baby Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.goNamed(RouteNames.login);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Subscription banner (free tier)
            subscriptionAsync.when(
              data: (sub) {
                if (sub == null || sub.isPremium) return const SizedBox.shrink();
                return _SubscriptionBanner(
                  used: sub.monthlyAnalysesUsed,
                  limit: sub.monthlyAnalysesLimit,
                  onUpgrade: () => context.pushNamed(RouteNames.subscription),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Start Kid Mode button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => context.pushNamed(RouteNames.childSelect),
                icon: const Icon(Icons.play_circle_filled, size: 28),
                label: const Text('Start Kid Mode',
                    style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Per-child stats
            Text(
              'Today\'s Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            statsAsync.when(
              data: (statsList) {
                if (statsList.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.child_care,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No children added yet'),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () =>
                                context.pushNamed(RouteNames.addChild),
                            child: const Text('Add a child'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: statsList
                      .map((s) => _ChildStatsCard(
                            stats: s,
                            onTap: () => context.pushNamed(
                              RouteNames.childActivity,
                              pathParameters: {'childId': s.child.id},
                            ),
                          ))
                      .toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading stats: $e'),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Quick actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickAction(
                  icon: Icons.block,
                  label: 'Filtered',
                  onTap: () => context.pushNamed(RouteNames.filteredContent),
                ),
                _QuickAction(
                  icon: Icons.tv,
                  label: 'Channels',
                  onTap: () => context.pushNamed(RouteNames.channelManagement),
                ),
                _QuickAction(
                  icon: Icons.tune,
                  label: 'Filters',
                  onTap: () => context.pushNamed(RouteNames.filterSettings),
                ),
                _QuickAction(
                  icon: Icons.timer,
                  label: 'Screen Time',
                  onTap: () => context.pushNamed(RouteNames.screenTimeSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildStatsCard extends StatelessWidget {
  final ChildDashboardStats stats;
  final VoidCallback onTap;

  const _ChildStatsCard({required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final age = AgeCalculator.yearsFromDob(stats.child.dateOfBirth);
    final bracket = AgeCalculator.ageBracket(stats.child.dateOfBirth);
    final limitText = stats.limitMinutesToday != null
        ? '/${stats.limitMinutesToday}m'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF6C63FF),
                    child: Text(
                      stats.child.name.isNotEmpty
                          ? stats.child.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stats.child.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Age $age · $bracket',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatBadge(
                    icon: Icons.timer,
                    value: '${stats.watchedMinutesToday}m$limitText',
                    label: 'watched',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _StatBadge(
                    icon: Icons.play_circle_outline,
                    value: '${stats.videosWatchedToday}',
                    label: 'videos',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _StatBadge(
                    icon: Icons.block,
                    value: '${stats.filteredToday}',
                    label: 'filtered',
                    color: Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _SubscriptionBanner extends StatelessWidget {
  final int used;
  final int limit;
  final VoidCallback onUpgrade;

  const _SubscriptionBanner({
    required this.used,
    required this.limit,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (used / limit).clamp(0.0, 1.0);
    final color = percentage > 0.8 ? Colors.red : Colors.blue;

    return Card(
      color: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Free Plan: $used/$limit analyses used',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.grey[200],
                    color: color,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: onUpgrade,
              child: const Text('Upgrade'),
            ),
          ],
        ),
      ),
    );
  }
}
