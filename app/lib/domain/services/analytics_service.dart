import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../data/datasources/remote/supabase_client.dart';
import '../../data/datasources/local/preferences_cache.dart';

/// Lightweight analytics events tracked during beta testing.
/// Events are stored in Supabase for analysis.
/// Respects user's analytics opt-in preference (GDPR compliant).
class AnalyticsService {
  static final _client = SupabaseClientWrapper.client;

  AnalyticsService._();

  /// Whether the user has opted in to analytics collection.
  /// Defaults to false (opt-in model for GDPR compliance).
  static bool get isOptedIn => PreferencesCache.analyticsOptedIn;

  /// Set the user's analytics preference.
  static set isOptedIn(bool value) {
    PreferencesCache.analyticsOptedIn = value;
  }

  /// Track a user event. Events are fire-and-forget.
  /// Respects the user's analytics opt-in setting.
  static Future<void> track(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    if (!isOptedIn) return;

    try {
      final userId = SupabaseClientWrapper.currentUserId;

      await _client.from('analytics_events').insert({
        'user_id': userId,
        'event_name': eventName,
        'properties': properties ?? {},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Analytics should never crash the app
    }
  }

  /// Hash an identifier to avoid storing raw child IDs in analytics.
  static String _hashId(String id) =>
      sha256.convert(utf8.encode(id)).toString().substring(0, 16);

  // Common event helpers

  static Future<void> trackScreenView(String screenName) =>
      track('screen_view', properties: {'screen': screenName});

  static Future<void> trackVideoPlayed(String videoId) =>
      track('video_played', properties: {'video_id': videoId});

  static Future<void> trackVideoFiltered(String videoId, String reason) =>
      track(
        'video_filtered',
        properties: {'video_id': videoId, 'reason': reason},
      );

  static Future<void> trackKidModeStarted(String childId) =>
      track('kid_mode_started', properties: {'child_id': _hashId(childId)});

  static Future<void> trackKidModeEnded(String childId, int durationSeconds) =>
      track(
        'kid_mode_ended',
        properties: {
          'child_id': _hashId(childId),
          'duration_s': durationSeconds,
        },
      );

  static Future<void> trackFilterAdjusted(String setting, dynamic value) =>
      track(
        'filter_adjusted',
        properties: {'setting': setting, 'value': '$value'},
      );

  static Future<void> trackFeedbackSubmitted(String category) =>
      track('feedback_submitted', properties: {'category': category});

  static Future<void> trackSubscriptionViewed() => track('subscription_viewed');

  static Future<void> trackError(String error, String context) =>
      track('app_error', properties: {'error': error, 'context': context});
}
