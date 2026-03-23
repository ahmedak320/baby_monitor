import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/datasources/local/preferences_cache.dart';
import '../data/datasources/remote/supabase_client.dart';

/// Provides a stable device ID, generating one on first launch.
final deviceIdProvider = FutureProvider<String>((ref) async {
  // Check local cache first
  var deviceId = PreferencesCache.deviceId;
  if (deviceId != null) return deviceId;

  // Generate a new device ID
  deviceId = const Uuid().v4();
  await PreferencesCache.setDeviceId(deviceId);

  return deviceId;
});

/// Registers the current device with Supabase.
Future<void> registerDevice(String deviceId) async {
  final userId = SupabaseClientWrapper.currentUserId;
  if (userId == null) return;

  final platform = Platform.isIOS ? 'ios' : 'android';
  final deviceName = Platform.localHostname;

  await SupabaseClientWrapper.client.from('devices').upsert(
    {
      'device_id': deviceId,
      'parent_id': userId,
      'device_name': deviceName,
      'platform': platform,
      'last_seen_at': DateTime.now().toIso8601String(),
    },
    onConflict: 'device_id',
  );
}

/// Updates the last_seen_at timestamp for this device.
Future<void> updateDeviceLastSeen(String deviceId) async {
  await SupabaseClientWrapper.client
      .from('devices')
      .update({'last_seen_at': DateTime.now().toIso8601String()}).eq(
          'device_id', deviceId);
}
