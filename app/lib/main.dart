import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/supabase_config.dart';
import 'data/datasources/local/local_cache.dart';
import 'data/datasources/remote/remote_config_service.dart';
import 'domain/services/background_sync_service.dart';
import 'utils/platform_info.dart';

final _backgroundSync = BackgroundSyncService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local caching
  await Hive.initFlutter();
  await LocalCache.initialize();

  // Detect TV platform
  await PlatformInfo.initialize();

  // Force landscape on TV
  if (PlatformInfo.isTV) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Load remote config (API keys, Piped instances) from Supabase
  await RemoteConfigService.instance.initialize();

  // Initialize RevenueCat (stub — real API key needed for production)
  try {
    final rcApiKey = SupabaseConfig.revenueCatApiKey;
    if (rcApiKey.isNotEmpty) {
      await Purchases.configure(PurchasesConfiguration(rcApiKey));
    }
  } catch (e) {
    debugPrint('RevenueCat init skipped: $e');
  }

  // Start background sync for approved video cache
  _backgroundSync.startPeriodicSync();

  runApp(const ProviderScope(child: BabyMonitorApp()));
}
