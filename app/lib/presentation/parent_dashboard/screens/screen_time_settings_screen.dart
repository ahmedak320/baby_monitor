import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/screen_time_repository.dart';

class ScreenTimeSettingsScreen extends ConsumerStatefulWidget {
  final String childId;
  final String childName;

  const ScreenTimeSettingsScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  ConsumerState<ScreenTimeSettingsScreen> createState() =>
      _ScreenTimeSettingsScreenState();
}

class _ScreenTimeSettingsScreenState
    extends ConsumerState<ScreenTimeSettingsScreen> {
  final _repo = ScreenTimeRepository();
  bool _isLoading = true;
  bool _isSaving = false;

  // Editable state
  bool _enabled = true;
  final Map<int, int?> _dailyLimits = {};
  int? _weeklyBudget;
  int _breakInterval = 30;
  int _breakDuration = 5;
  int? _bedtimeHour;
  int? _bedtimeMinute;
  int? _wakeupHour;
  int? _wakeupMinute;
  int _winddown = 5;
  bool _useWeeklyBudget = false;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final rules = await _repo.getRules(widget.childId);
    setState(() {
      _isLoading = false;
      if (rules != null) {
        _enabled = rules.isEnabled;
        _dailyLimits.addAll(rules.dailyLimits);
        _weeklyBudget = rules.weeklyBudgetMinutes;
        _useWeeklyBudget = rules.weeklyBudgetMinutes != null;
        _breakInterval = rules.breakIntervalMinutes;
        _breakDuration = rules.breakDurationMinutes;
        _bedtimeHour = rules.bedtimeHour;
        _bedtimeMinute = rules.bedtimeMinute;
        _wakeupHour = rules.wakeupHour;
        _wakeupMinute = rules.wakeupMinute;
        _winddown = rules.winddownWarningMinutes;
      } else {
        // Defaults: 2 hours weekdays, 3 hours weekends
        for (int i = 1; i <= 5; i++) {
          _dailyLimits[i] = 120;
        }
        for (int i = 6; i <= 7; i++) {
          _dailyLimits[i] = 180;
        }
        _bedtimeHour = 19;
        _bedtimeMinute = 0;
        _wakeupHour = 7;
        _wakeupMinute = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.childName} - Screen Time')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.childName} - Screen Time'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveRules,
            child: _isSaving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable/disable
          SwitchListTile(
            title: const Text('Screen Time Limits'),
            subtitle: const Text('Enable time tracking and enforcement'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),

          if (_enabled) ...[
            const Divider(height: 32),

            // Daily vs Weekly toggle
            _SectionHeader('Time Limits'),
            SwitchListTile(
              title: const Text('Use weekly budget'),
              subtitle: const Text('Set a total weekly allowance instead of daily'),
              value: _useWeeklyBudget,
              onChanged: (v) => setState(() => _useWeeklyBudget = v),
            ),

            if (_useWeeklyBudget) ...[
              ListTile(
                title: const Text('Weekly budget'),
                subtitle: Text('${_weeklyBudget ?? 840} minutes (${((_weeklyBudget ?? 840) / 60).toStringAsFixed(1)} hours)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showMinutesPicker('Weekly Budget', _weeklyBudget ?? 840, (v) {
                  setState(() => _weeklyBudget = v);
                }),
              ),
            ] else ...[
              // Per-day limits
              for (int day = 1; day <= 7; day++)
                ListTile(
                  title: Text(_dayNames[day - 1]),
                  subtitle: Text(_dailyLimits[day] != null
                      ? '${_dailyLimits[day]} min (${(_dailyLimits[day]! / 60).toStringAsFixed(1)}h)'
                      : 'No limit'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_dailyLimits[day] != null)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => setState(() => _dailyLimits[day] = null),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _showMinutesPicker(
                    _dayNames[day - 1],
                    _dailyLimits[day] ?? 120,
                    (v) => setState(() => _dailyLimits[day] = v),
                  ),
                ),
            ],

            const Divider(height: 32),

            // Break settings
            _SectionHeader('Breaks'),
            ListTile(
              title: const Text('Break every'),
              subtitle: Text('$_breakInterval minutes'),
              onTap: () => _showMinutesPicker('Break Interval', _breakInterval, (v) {
                setState(() => _breakInterval = v);
              }, max: 120),
            ),
            ListTile(
              title: const Text('Break duration'),
              subtitle: Text('$_breakDuration minutes'),
              onTap: () => _showMinutesPicker('Break Duration', _breakDuration, (v) {
                setState(() => _breakDuration = v);
              }, max: 30),
            ),

            const Divider(height: 32),

            // Bedtime
            _SectionHeader('Bedtime'),
            ListTile(
              title: const Text('Bedtime'),
              subtitle: Text(_bedtimeHour != null
                  ? _formatTime(_bedtimeHour!, _bedtimeMinute ?? 0)
                  : 'Not set'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_bedtimeHour != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () => setState(() {
                        _bedtimeHour = null;
                        _bedtimeMinute = null;
                      }),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _pickTime(
                initial: TimeOfDay(
                  hour: _bedtimeHour ?? 19,
                  minute: _bedtimeMinute ?? 0,
                ),
                onPicked: (t) => setState(() {
                  _bedtimeHour = t.hour;
                  _bedtimeMinute = t.minute;
                }),
              ),
            ),
            ListTile(
              title: const Text('Wake-up time'),
              subtitle: Text(_wakeupHour != null
                  ? _formatTime(_wakeupHour!, _wakeupMinute ?? 0)
                  : 'Not set'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_wakeupHour != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () => setState(() {
                        _wakeupHour = null;
                        _wakeupMinute = null;
                      }),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _pickTime(
                initial: TimeOfDay(
                  hour: _wakeupHour ?? 7,
                  minute: _wakeupMinute ?? 0,
                ),
                onPicked: (t) => setState(() {
                  _wakeupHour = t.hour;
                  _wakeupMinute = t.minute;
                }),
              ),
            ),

            const Divider(height: 32),

            // Winddown
            _SectionHeader('Winddown Warning'),
            ListTile(
              title: const Text('Warn before time\'s up'),
              subtitle: Text('$_winddown minutes before'),
              onTap: () => _showMinutesPicker('Winddown', _winddown, (v) {
                setState(() => _winddown = v);
              }, max: 15),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveRules() async {
    setState(() => _isSaving = true);

    final rules = ScreenTimeRules(
      childId: widget.childId,
      dailyLimits: _useWeeklyBudget ? {} : _dailyLimits,
      weeklyBudgetMinutes: _useWeeklyBudget ? _weeklyBudget : null,
      breakIntervalMinutes: _breakInterval,
      breakDurationMinutes: _breakDuration,
      bedtimeHour: _bedtimeHour,
      bedtimeMinute: _bedtimeMinute,
      wakeupHour: _wakeupHour,
      wakeupMinute: _wakeupMinute,
      winddownWarningMinutes: _winddown,
      isEnabled: _enabled,
    );

    await _repo.saveRules(rules);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screen time rules saved')),
      );
      Navigator.of(context).pop();
    }
  }

  void _showMinutesPicker(
    String title,
    int current,
    ValueChanged<int> onChanged, {
    int max = 480,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        int value = current;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$value minutes',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Slider(
                  value: value.toDouble(),
                  min: 5,
                  max: max.toDouble(),
                  divisions: (max - 5) ~/ 5,
                  label: '$value min',
                  onChanged: (v) => setDialogState(() => value = v.round()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  onChanged(value);
                  Navigator.pop(context);
                },
                child: const Text('Set'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickTime({
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) onPicked(picked);
  }

  String _formatTime(int hour, int minute) {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final amPm = hour >= 12 ? 'PM' : 'AM';
    return '$h:${minute.toString().padLeft(2, '0')} $amPm';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
