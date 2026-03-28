import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/utils/platform_info.dart';

void main() {
  group('PlatformInfo', () {
    tearDown(() {
      PlatformInfo.clearTestOverride();
    });

    test('defaults to mobile (non-TV)', () {
      // Without initialization, should default to non-TV
      PlatformInfo.clearTestOverride();
      expect(PlatformInfo.isTV, isFalse);
      expect(PlatformInfo.isMobile, isTrue);
      expect(PlatformInfo.tvPlatform, TvPlatform.none);
    });

    test('overrideForTest sets TV mode', () {
      PlatformInfo.overrideForTest(
        isTV: true,
        tvPlatform: TvPlatform.androidTV,
      );

      expect(PlatformInfo.isTV, isTrue);
      expect(PlatformInfo.isMobile, isFalse);
      expect(PlatformInfo.tvPlatform, TvPlatform.androidTV);
    });

    test('overrideForTest sets Fire TV', () {
      PlatformInfo.overrideForTest(isTV: true, tvPlatform: TvPlatform.fireTV);

      expect(PlatformInfo.isTV, isTrue);
      expect(PlatformInfo.tvPlatform, TvPlatform.fireTV);
    });

    test('clearTestOverride resets to default', () {
      PlatformInfo.overrideForTest(isTV: true);
      expect(PlatformInfo.isTV, isTrue);

      PlatformInfo.clearTestOverride();
      expect(PlatformInfo.isTV, isFalse);
    });

    test('isMobile is inverse of isTV', () {
      PlatformInfo.overrideForTest(isTV: true);
      expect(PlatformInfo.isMobile, isFalse);

      PlatformInfo.overrideForTest(isTV: false);
      expect(PlatformInfo.isMobile, isTrue);
    });
  });
}
