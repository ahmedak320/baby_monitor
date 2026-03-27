import 'supabase_config.dart';

/// Centralized app configuration from compile-time environment variables.
class AppConfig {
  AppConfig._();

  static String get supabaseUrl => SupabaseConfig.supabaseUrl;
  static String get supabaseAnonKey => SupabaseConfig.supabaseAnonKey;
}
