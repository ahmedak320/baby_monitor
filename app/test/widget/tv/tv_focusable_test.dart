import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baby_monitor/utils/platform_info.dart';
import 'package:baby_monitor/presentation/kid_mode/tv/tv_focusable.dart';

void main() {
  setUp(() {
    PlatformInfo.overrideForTest(isTV: true, tvPlatform: TvPlatform.androidTV);
  });

  tearDown(() {
    PlatformInfo.clearTestOverride();
  });

  group('TvFocusable', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              child: const Text('Test'),
              onSelect: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('shows focus border when focused on TV', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              autofocus: true,
              child: const Text('Focused'),
              onSelect: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // The AnimatedContainer should be present
      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('triggers onSelect with Enter key', (tester) async {
      var selected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              autofocus: true,
              child: const Text('Selectable'),
              onSelect: () => selected = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(selected, isTrue);
    });

    testWidgets('on mobile, wraps with GestureDetector instead', (tester) async {
      PlatformInfo.overrideForTest(isTV: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              child: const Text('Mobile'),
              onSelect: () {},
            ),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsOneWidget);
      // No AnimatedContainer on mobile
      expect(find.byType(AnimatedContainer), findsNothing);
    });
  });
}
