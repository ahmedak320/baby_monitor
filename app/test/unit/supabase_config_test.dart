import 'package:baby_monitor/config/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('required app config is reported missing in test environment', () {
    expect(
      SupabaseConfig.missingRequiredAppConfig,
      containsAll(['SUPABASE_URL', 'SUPABASE_ANON_KEY']),
    );
    expect(SupabaseConfig.hasRequiredAppConfig, isFalse);
  });
}
