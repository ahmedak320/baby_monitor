/// Compile-time configuration for Supabase.
/// Values injected via --dart-define at build time.
class SupabaseConfig {
  SupabaseConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const youtubeApiKey = String.fromEnvironment('YOUTUBE_API_KEY', defaultValue: '');
  static const youtubeApiKeys = String.fromEnvironment('YOUTUBE_API_KEYS', defaultValue: '');
  static const pipedInstances = String.fromEnvironment('PIPED_INSTANCES', defaultValue: 'https://pipedapi.kavin.rocks');
  static const revenueCatApiKey = String.fromEnvironment('REVENUECAT_API_KEY', defaultValue: '');
}
