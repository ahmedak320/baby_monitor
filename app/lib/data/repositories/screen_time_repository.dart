import '../datasources/remote/supabase_client.dart';

/// Screen time rules for a child.
class ScreenTimeRules {
  final String childId;
  final Map<int, int?> dailyLimits; // 1=Mon..7=Sun -> minutes (null=no limit)
  final int? weeklyBudgetMinutes;
  final int breakIntervalMinutes;
  final int breakDurationMinutes;
  final int? bedtimeHour;
  final int? bedtimeMinute;
  final int? wakeupHour;
  final int? wakeupMinute;
  final int winddownWarningMinutes;
  final bool isEnabled;

  const ScreenTimeRules({
    required this.childId,
    this.dailyLimits = const {},
    this.weeklyBudgetMinutes,
    this.breakIntervalMinutes = 30,
    this.breakDurationMinutes = 5,
    this.bedtimeHour,
    this.bedtimeMinute,
    this.wakeupHour,
    this.wakeupMinute,
    this.winddownWarningMinutes = 5,
    this.isEnabled = true,
  });

  /// Get today's daily limit in minutes (null = no limit).
  int? get todayLimit {
    final weekday = DateTime.now().weekday; // 1=Mon..7=Sun
    return dailyLimits[weekday];
  }

  factory ScreenTimeRules.fromJson(Map<String, dynamic> json) {
    return ScreenTimeRules(
      childId: json['child_id'] as String,
      dailyLimits: {
        1: json['mon_limit'] as int?,
        2: json['tue_limit'] as int?,
        3: json['wed_limit'] as int?,
        4: json['thu_limit'] as int?,
        5: json['fri_limit'] as int?,
        6: json['sat_limit'] as int?,
        7: json['sun_limit'] as int?,
      },
      weeklyBudgetMinutes: json['weekly_budget_minutes'] as int?,
      breakIntervalMinutes: json['break_interval_minutes'] as int? ?? 30,
      breakDurationMinutes: json['break_duration_minutes'] as int? ?? 5,
      bedtimeHour: json['bedtime_hour'] as int?,
      bedtimeMinute: json['bedtime_minute'] as int?,
      wakeupHour: json['wakeup_hour'] as int?,
      wakeupMinute: json['wakeup_minute'] as int?,
      winddownWarningMinutes: json['winddown_warning_minutes'] as int? ?? 5,
      isEnabled: json['is_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'child_id': childId,
    'mon_limit': dailyLimits[1],
    'tue_limit': dailyLimits[2],
    'wed_limit': dailyLimits[3],
    'thu_limit': dailyLimits[4],
    'fri_limit': dailyLimits[5],
    'sat_limit': dailyLimits[6],
    'sun_limit': dailyLimits[7],
    'weekly_budget_minutes': weeklyBudgetMinutes,
    'break_interval_minutes': breakIntervalMinutes,
    'break_duration_minutes': breakDurationMinutes,
    'bedtime_hour': bedtimeHour,
    'bedtime_minute': bedtimeMinute,
    'wakeup_hour': wakeupHour,
    'wakeup_minute': wakeupMinute,
    'winddown_warning_minutes': winddownWarningMinutes,
    'is_enabled': isEnabled,
  };
}

/// Repository for screen time rules and sessions.
class ScreenTimeRepository {
  final _client = SupabaseClientWrapper.client;

  /// Get rules for a child.
  Future<ScreenTimeRules?> getRules(String childId) async {
    final row = await _client
        .from('screen_time_rules')
        .select()
        .eq('child_id', childId)
        .maybeSingle();
    if (row == null) return null;
    return ScreenTimeRules.fromJson(row);
  }

  /// Save/update rules for a child.
  Future<void> saveRules(ScreenTimeRules rules) async {
    await _client
        .from('screen_time_rules')
        .upsert(rules.toJson(), onConflict: 'child_id');
  }

  /// Get total usage for a child today (across all devices).
  Future<int> getTodayUsageSeconds(String childId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final rows = await _client
        .from('screen_time_sessions')
        .select('duration_seconds')
        .eq('child_id', childId)
        .eq('date', today);

    int total = 0;
    for (final row in rows as List) {
      total += (row['duration_seconds'] as int?) ?? 0;
    }
    return total;
  }

  /// Get total usage for a child this week.
  Future<int> getWeekUsageSeconds(String childId) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartStr = weekStart.toIso8601String().split('T').first;

    final rows = await _client
        .from('screen_time_sessions')
        .select('duration_seconds')
        .eq('child_id', childId)
        .gte('date', weekStartStr);

    int total = 0;
    for (final row in rows as List) {
      total += (row['duration_seconds'] as int?) ?? 0;
    }
    return total;
  }

  /// Start a new screen time session.
  Future<String> startSession({
    required String childId,
    required String deviceId,
  }) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final row = await _client
        .from('screen_time_sessions')
        .insert({
          'child_id': childId,
          'device_id': deviceId,
          'started_at': DateTime.now().toIso8601String(),
          'date': today,
          'duration_seconds': 0,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Update session duration.
  Future<void> updateSessionDuration(String sessionId, int seconds) async {
    await _client
        .from('screen_time_sessions')
        .update({'duration_seconds': seconds})
        .eq('id', sessionId);
  }

  /// End a session.
  Future<void> endSession(String sessionId, int totalSeconds) async {
    await _client
        .from('screen_time_sessions')
        .update({
          'ended_at': DateTime.now().toIso8601String(),
          'duration_seconds': totalSeconds,
        })
        .eq('id', sessionId);
  }
}
