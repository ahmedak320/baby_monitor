import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/services/age_transition_service.dart';
import '../../../domain/services/notification_service.dart';
import '../../../presentation/auth/providers/auth_provider.dart';
import '../../../providers/subscription_provider.dart';
import '../../../routing/route_names.dart';
import '../../../utils/age_calculator.dart';
import '../providers/dashboard_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/age_transition_dialog.dart';
import '../widgets/notification_banner.dart';

/// Tablet-optimized dashboard with split view:
/// Left panel shows child list + quick actions,
/// Right panel shows detail for selected child.
class TabletDashboardScreen extends ConsumerStatefulWidget {
  const TabletDashboardScreen({super.key});

  @override
  ConsumerState<TabletDashboardScreen> createState() =>
      _TabletDashboardScreenState();
}

class _TabletDashboardScreenState
    extends ConsumerState<TabletDashboardScreen> {
  String? _selectedChildId;
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
    final notificationsAsync = ref.watch(pendingNotificationsProvider);

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
      body: Row(
        children: [
          // Left panel: child list + actions
          SizedBox(
            width: 360,
            child: _LeftPanel(
              statsAsync: statsAsync,
              subscriptionAsync: subscriptionAsync,
              notificationsAsync: notificationsAsync,
              selectedChildId: _selectedChildId,
              onChildSelected: (id) =>
                  setState(() => _selectedChildId = id),
              ref: ref,
            ),
          ),
          const VerticalDivider(width: 1),
          // Right panel: selected child detail
          Expanded(
            child: _RightPanel(
              selectedChildId: _selectedChildId,
              statsAsync: statsAsync,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftPanel extends StatelessWidget {
  final AsyncValue<List<ChildDashboardStats>> statsAsync;
  final AsyncValue subscriptionAsync;
  final AsyncValue<List<AppNotification>> notificationsAsync;
  final String? selectedChildId;
  final ValueChanged<String> onChildSelected;
  final WidgetRef ref;

  const _LeftPanel({
    required this.statsAsync,
    required this.subscriptionAsync,
    required this.notificationsAsync,
    required this.selectedChildId,
    required this.onChildSelected,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Notifications
        notificationsAsync.when(
          data: (notifications) => Column(
            children: notifications.map((n) {
              return NotificationBanner(
                notification: n,
                onDismiss: () {
                  NotificationService().markShown(n.type);
                  ref.invalidate(pendingNotificationsProvider);
                },
              );
            }).toList(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        // Start Kid Mode
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () =>
                context.pushNamed(RouteNames.childSelect),
            icon: const Icon(Icons.play_circle_filled),
            label: const Text('Start Kid Mode'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Children
        Text(
          'Children',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        statsAsync.when(
          data: (statsList) {
            if (statsList.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.child_care, size: 40, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('No children added yet'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => context.pushNamed(RouteNames.addChild),
                        icon: const Icon(Icons.add),
                        label: const Text('Add a child'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: statsList.map((s) {
                final isSelected = s.child.id == selectedChildId;
                return _CompactChildTile(
                  stats: s,
                  isSelected: isSelected,
                  onTap: () => onChildSelected(s.child.id),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Column(
            children: [
              Text('Error: $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => context.pushNamed(RouteNames.addChild),
                icon: const Icon(Icons.add),
                label: const Text('Add a child'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Quick actions (vertical on tablet side panel)
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        _SidebarAction(
          icon: Icons.block,
          label: 'Filtered Content',
          onTap: () => context.pushNamed(RouteNames.filteredContent),
        ),
        _SidebarAction(
          icon: Icons.tv,
          label: 'Channels',
          onTap: () => context.pushNamed(RouteNames.channelManagement),
        ),
        _SidebarAction(
          icon: Icons.tune,
          label: 'Filter Settings',
          onTap: () => context.pushNamed(RouteNames.filterSettings),
        ),
        _SidebarAction(
          icon: Icons.timer,
          label: 'Screen Time',
          onTap: () => context.pushNamed(RouteNames.screenTimeSettings),
        ),
        _SidebarAction(
          icon: Icons.star,
          label: 'Subscription',
          onTap: () => context.pushNamed(RouteNames.subscription),
        ),
      ],
    );
  }
}

class _CompactChildTile extends StatelessWidget {
  final ChildDashboardStats stats;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactChildTile({
    required this.stats,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final age = AgeCalculator.yearsFromDob(stats.child.dateOfBirth);
    final bracket = AgeCalculator.ageBracket(stats.child.dateOfBirth);

    return Card(
      color: isSelected
          ? const Color(0xFF6C63FF).withValues(alpha: 0.08)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Color(0xFF6C63FF), width: 2)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
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
        title: Text(stats.child.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Age $age · $bracket'),
        trailing: Text(
          '${stats.watchedMinutesToday}m',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SidebarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(label),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _RightPanel extends StatelessWidget {
  final String? selectedChildId;
  final AsyncValue<List<ChildDashboardStats>> statsAsync;

  const _RightPanel({
    required this.selectedChildId,
    required this.statsAsync,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedChildId == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select a child to view details',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return statsAsync.when(
      data: (statsList) {
        final stats = statsList.where((s) => s.child.id == selectedChildId);
        if (stats.isEmpty) {
          return const Center(child: Text('Child not found'));
        }

        final s = stats.first;
        final age = AgeCalculator.yearsFromDob(s.child.dateOfBirth);
        final bracket = AgeCalculator.ageBracket(s.child.dateOfBirth);
        final limitText = s.limitMinutesToday != null
            ? ' / ${s.limitMinutesToday}m limit'
            : '';

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFF6C63FF),
                  child: Text(
                    s.child.name.isNotEmpty
                        ? s.child.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.child.name,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Age $age · $bracket',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => context.pushNamed(
                    RouteNames.childActivity,
                    pathParameters: {'childId': s.child.id},
                  ),
                  child: const Text('View Activity'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Stats grid
            Row(
              children: [
                _StatCard(
                  icon: Icons.timer,
                  value: '${s.watchedMinutesToday}m$limitText',
                  label: 'Screen Time Today',
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.play_circle_outline,
                  value: '${s.videosWatchedToday}',
                  label: 'Videos Watched',
                  color: Colors.green,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.block,
                  value: '${s.filteredToday}',
                  label: 'Videos Filtered',
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
