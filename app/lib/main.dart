import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/supabase_config.dart';
import 'data/datasources/local/local_cache.dart';
import 'data/datasources/local/preferences_cache.dart';
import 'data/datasources/remote/remote_config_service.dart';
import 'data/datasources/remote/supabase_client.dart';
import 'data/repositories/profile_repository.dart';
import 'domain/services/background_sync_service.dart';
import 'utils/platform_info.dart';

final _backgroundSync = BackgroundSyncService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
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

    final missingConfig = SupabaseConfig.missingRequiredAppConfig;
    if (missingConfig.isNotEmpty) {
      runApp(
        _BootstrapErrorApp(
          title: 'Missing app configuration',
          message:
              'This build is missing required runtime values: '
              '${missingConfig.join(', ')}.\n\n'
              'Run Flutter with --dart-define-from-file=.env so the app can '
              'initialize Supabase before loading the UI.',
        ),
      );
      return;
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

    // Rehydrate local cache for returning users whose Hive data was cleared
    // but Supabase session persists (different storage backends).
    if (SupabaseClientWrapper.isAuthenticated &&
        PreferencesCache.lastChildId == null) {
      try {
        final children = await ProfileRepository().getChildren();
        if (children.isNotEmpty) {
          await PreferencesCache.setLastChildId(children.first.id);
        }
      } catch (_) {
        // Non-fatal — setup guard will redirect to onboarding as fallback.
      }
    }

    // Start background sync for approved video cache
    _backgroundSync.startPeriodicSync();

    runApp(const ProviderScope(child: BabyMonitorApp()));
  } catch (e, stackTrace) {
    debugPrint('App bootstrap failed: $e');
    debugPrintStack(stackTrace: stackTrace);

    runApp(
      _BootstrapErrorApp(
        title: 'Startup failed',
        message:
            'The app could not finish initialization.\n\n'
            '$e\n\n'
            'Check your .env values and emulator health, then restart the app.',
      ),
    );
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  final String title;
  final String message;

  const _BootstrapErrorApp({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF171717),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF303030)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFFD4D4D4),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
