import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized app configuration from environment variables.
class AppConfig {
  AppConfig._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
