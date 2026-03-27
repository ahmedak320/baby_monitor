import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'data/datasources/local/local_cache.dart';
import 'domain/services/background_sync_service.dart';

final _backgroundSync = BackgroundSyncService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive for local caching
  await Hive.initFlutter();
  await LocalCache.initialize();

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Initialize RevenueCat (stub — real API key needed for production)
  try {
    final rcApiKey = dotenv.env['REVENUECAT_API_KEY'] ?? '';
    if (rcApiKey.isNotEmpty) {
      await Purchases.configure(PurchasesConfiguration(rcApiKey));
    }
  } catch (e) {
    debugPrint('RevenueCat init skipped: $e');
  }

  // Start background sync for approved video cache
  _backgroundSync.startPeriodicSync();

  runApp(
    const ProviderScope(
      child: BabyMonitorApp(),
    ),
  );
}
