import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/screen_time_repository.dart';

/// Current screen time state for a child.
enum ScreenTimeStatus {
  active, // Normal watching
  winddown, // Warning: time almost up
  breakTime, // Mandatory break
  timeUp, // Daily limit reached
  bedtime, // It's bedtime
  beforeWakeup, // Before allowed start time
}

class ScreenTimeState {
  final ScreenTimeStatus status;
  final int usedSecondsToday;
  final int? limitSecondsToday; // null = no limit
  final int secondsSinceLastBreak;
  final int breakDurationSeconds;
  final int winddownWarningSeconds;
  final String? sessionId;

  const ScreenTimeState({
    this.status = ScreenTimeStatus.active,
    this.usedSecondsToday = 0,
    this.limitSecondsToday,
    this.secondsSinceLastBreak = 0,
    this.breakDurationSeconds = 300,
    this.winddownWarningSeconds = 300,
    this.sessionId,
  });

  /// Seconds remaining before limit hit (null = unlimited).
  int? get remainingSeconds {
    if (limitSecondsToday == null) return null;
    return (limitSecondsToday! - usedSecondsToday).clamp(0, limitSecondsToday!);
  }

  /// Minutes remaining (for display).
  int? get remainingMinutes =>
      remainingSeconds != null ? (remainingSeconds! / 60).ceil() : null;

  /// Seconds until next break.
  int get secondsUntilBreak {
    final breakInterval = 1800; // default 30 min
    return (breakInterval - secondsSinceLastBreak).clamp(0, breakInterval);
  }

  ScreenTimeState copyWith({
    ScreenTimeStatus? status,
    int? usedSecondsToday,
    int? limitSecondsToday,
    int? secondsSinceLastBreak,
    int? breakDurationSeconds,
    int? winddownWarningSeconds,
    String? sessionId,
  }) {
    return ScreenTimeState(
      status: status ?? this.status,
      usedSecondsToday: usedSecondsToday ?? this.usedSecondsToday,
      limitSecondsToday: limitSecondsToday ?? this.limitSecondsToday,
      secondsSinceLastBreak:
          secondsSinceLastBreak ?? this.secondsSinceLastBreak,
      breakDurationSeconds: breakDurationSeconds ?? this.breakDurationSeconds,
      winddownWarningSeconds:
          winddownWarningSeconds ?? this.winddownWarningSeconds,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

/// Service that tracks and enforces screen time limits.
class ScreenTimeNotifier extends StateNotifier<ScreenTimeState> {
  final ScreenTimeRepository _repo;
  Timer? _ticker;
  ScreenTimeRules? _rules;
  ScreenTimeNotifier(this._repo) : super(const ScreenTimeState());

  /// Initialize screen time tracking for a child.
  Future<void> startTracking({
    required String childId,
    required String deviceId,
  }) async {
    // Load rules
    _rules = await _repo.getRules(childId);

    // Get today's usage (cross-device)
    final usedToday = await _repo.getTodayUsageSeconds(childId);

    // Calculate today's limit
    int? limitSeconds;
    if (_rules != null && _rules!.isEnabled) {
      final todayLimit = _rules!.todayLimit;
      if (todayLimit != null) {
        limitSeconds = todayLimit * 60;
      } else if (_rules!.weeklyBudgetMinutes != null) {
        // Weekly budget: calculate remaining
        final weekUsed = await _repo.getWeekUsageSeconds(childId);
        final weekBudgetSeconds = _rules!.weeklyBudgetMinutes! * 60;
        limitSeconds = (weekBudgetSeconds - weekUsed).clamp(
          0,
          weekBudgetSeconds,
        );
      }
    }

    // Start a new session
    final sessionId = await _repo.startSession(
      childId: childId,
      deviceId: deviceId,
    );

    // Check initial status
    final initialStatus = _checkStatus(
      usedToday,
      limitSeconds,
      0, // fresh break counter
    );

    state = ScreenTimeState(
      status: initialStatus,
      usedSecondsToday: usedToday,
      limitSecondsToday: limitSeconds,
      secondsSinceLastBreak: 0,
      breakDurationSeconds: (_rules?.breakDurationMinutes ?? 5) * 60,
      winddownWarningSeconds: (_rules?.winddownWarningMinutes ?? 5) * 60,
      sessionId: sessionId,
    );

    // Start the per-second ticker
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Stop tracking (when exiting kid mode).
  Future<void> stopTracking() async {
    _ticker?.cancel();
    _ticker = null;

    if (state.sessionId != null) {
      // Save final session duration
      final sessionDuration = state.usedSecondsToday; // approximate
      await _repo.endSession(state.sessionId!, sessionDuration);
    }

    state = const ScreenTimeState();
  }

  /// Called after a break is completed.
  void breakCompleted() {
    state = state.copyWith(
      status: ScreenTimeStatus.active,
      secondsSinceLastBreak: 0,
    );
  }

  void _tick() {
    if (state.status == ScreenTimeStatus.breakTime ||
        state.status == ScreenTimeStatus.timeUp ||
        state.status == ScreenTimeStatus.bedtime) {
      return; // Don't count time during breaks/lockout
    }

    final newUsed = state.usedSecondsToday + 1;
    final newBreakCounter = state.secondsSinceLastBreak + 1;

    final newStatus = _checkStatus(
      newUsed,
      state.limitSecondsToday,
      newBreakCounter,
    );

    state = state.copyWith(
      status: newStatus,
      usedSecondsToday: newUsed,
      secondsSinceLastBreak: newBreakCounter,
    );

    // Periodically save session progress (every 30s)
    if (newUsed % 30 == 0 && state.sessionId != null) {
      _repo.updateSessionDuration(state.sessionId!, newUsed);
    }
  }

  ScreenTimeStatus _checkStatus(
    int usedSeconds,
    int? limitSeconds,
    int breakCounter,
  ) {
    // Check bedtime
    if (_rules != null && _isBedtime()) {
      return ScreenTimeStatus.bedtime;
    }

    // Check before wakeup
    if (_rules != null && _isBeforeWakeup()) {
      return ScreenTimeStatus.beforeWakeup;
    }

    // Check time's up
    if (limitSeconds != null && usedSeconds >= limitSeconds) {
      return ScreenTimeStatus.timeUp;
    }

    // Check break time
    final breakInterval = (_rules?.breakIntervalMinutes ?? 30) * 60;
    if (breakCounter >= breakInterval) {
      return ScreenTimeStatus.breakTime;
    }

    // Check winddown
    if (limitSeconds != null) {
      final remaining = limitSeconds - usedSeconds;
      final winddownThreshold = (_rules?.winddownWarningMinutes ?? 5) * 60;
      if (remaining <= winddownThreshold && remaining > 0) {
        return ScreenTimeStatus.winddown;
      }
    }

    return ScreenTimeStatus.active;
  }

  bool _isBedtime() {
    if (_rules?.bedtimeHour == null) return false;
    final now = DateTime.now();
    final bedtime = DateTime(
      now.year,
      now.month,
      now.day,
      _rules!.bedtimeHour!,
      _rules!.bedtimeMinute ?? 0,
    );
    return now.isAfter(bedtime);
  }

  bool _isBeforeWakeup() {
    if (_rules?.wakeupHour == null) return false;
    final now = DateTime.now();
    final wakeup = DateTime(
      now.year,
      now.month,
      now.day,
      _rules!.wakeupHour!,
      _rules!.wakeupMinute ?? 0,
    );
    return now.isBefore(wakeup);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Provides the screen time state notifier.
final screenTimeProvider =
    StateNotifierProvider<ScreenTimeNotifier, ScreenTimeState>((ref) {
      return ScreenTimeNotifier(ScreenTimeRepository());
    });
