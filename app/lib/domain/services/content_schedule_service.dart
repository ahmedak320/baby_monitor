import '../../data/datasources/remote/supabase_client.dart';

/// A time block with allowed content types.
class ContentScheduleBlock {
  final String id;
  final String childId;
  final int? dayOfWeek; // 0=Mon..6=Sun, null=every day
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final List<String> allowedContentTypes;
  final bool isEnabled;

  const ContentScheduleBlock({
    required this.id,
    required this.childId,
    this.dayOfWeek,
    required this.startHour,
    this.startMinute = 0,
    required this.endHour,
    this.endMinute = 0,
    required this.allowedContentTypes,
    this.isEnabled = true,
  });

  factory ContentScheduleBlock.fromJson(Map<String, dynamic> json) {
    return ContentScheduleBlock(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      dayOfWeek: json['day_of_week'] as int?,
      startHour: json['start_hour'] as int,
      startMinute: json['start_minute'] as int? ?? 0,
      endHour: json['end_hour'] as int,
      endMinute: json['end_minute'] as int? ?? 0,
      allowedContentTypes:
          (json['allowed_content_types'] as List?)?.cast<String>() ?? [],
      isEnabled: json['is_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'child_id': childId,
    'day_of_week': dayOfWeek,
    'start_hour': startHour,
    'start_minute': startMinute,
    'end_hour': endHour,
    'end_minute': endMinute,
    'allowed_content_types': allowedContentTypes,
    'is_enabled': isEnabled,
  };

  /// Check if this block is active right now.
  bool isActiveNow() {
    final now = DateTime.now();
    // Check day of week
    if (dayOfWeek != null && now.weekday - 1 != dayOfWeek) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }
}

/// Service for managing content schedules (premium feature).
class ContentScheduleService {
  final _client = SupabaseClientWrapper.client;

  /// Get all schedule blocks for a child.
  Future<List<ContentScheduleBlock>> getSchedule(String childId) async {
    final rows = await _client
        .from('content_schedules')
        .select()
        .eq('child_id', childId)
        .order('start_hour');

    return (rows as List)
        .map((r) => ContentScheduleBlock.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Get currently allowed content types based on active schedule.
  Future<List<String>?> getCurrentAllowedTypes(String childId) async {
    final blocks = await getSchedule(childId);
    final activeBlocks = blocks.where((b) => b.isEnabled && b.isActiveNow());

    if (activeBlocks.isEmpty) return null; // No schedule = all types allowed

    // Merge all allowed types from active blocks
    final types = <String>{};
    for (final block in activeBlocks) {
      types.addAll(block.allowedContentTypes);
    }
    return types.toList();
  }

  /// Add a schedule block.
  Future<void> addBlock(ContentScheduleBlock block) async {
    await _client.from('content_schedules').insert(block.toJson());
  }

  /// Update a schedule block.
  Future<void> updateBlock(String blockId, Map<String, dynamic> updates) async {
    await _client.from('content_schedules').update(updates).eq('id', blockId);
  }

  /// Delete a schedule block.
  Future<void> deleteBlock(String blockId) async {
    await _client.from('content_schedules').delete().eq('id', blockId);
  }

  /// Apply a preset schedule template.
  Future<void> applyTemplate(String childId, String templateName) async {
    // Clear existing schedule
    await _client.from('content_schedules').delete().eq('child_id', childId);

    final blocks = _templates[templateName];
    if (blocks == null) return;

    for (final block in blocks) {
      await _client.from('content_schedules').insert({
        ...block,
        'child_id': childId,
      });
    }
  }

  static const _templates = {
    'balanced_day': [
      {
        'start_hour': 8,
        'end_hour': 12,
        'allowed_content_types': ['educational', 'nature', 'creative'],
      },
      {
        'start_hour': 12,
        'end_hour': 17,
        'allowed_content_types': ['cartoons', 'music', 'fun'],
      },
      {
        'start_hour': 17,
        'end_hour': 19,
        'allowed_content_types': ['storytime', 'soothing', 'nature'],
      },
    ],
    'learning_focus': [
      {
        'start_hour': 8,
        'end_hour': 15,
        'allowed_content_types': ['educational', 'nature', 'creative'],
      },
      {
        'start_hour': 15,
        'end_hour': 19,
        'allowed_content_types': ['cartoons', 'music', 'storytime'],
      },
    ],
    'calm_creative': [
      {
        'start_hour': 8,
        'end_hour': 19,
        'allowed_content_types': [
          'soothing',
          'nature',
          'creative',
          'storytime',
          'music',
        ],
      },
    ],
  };

  static List<String> get templateNames => _templates.keys.toList();
}
