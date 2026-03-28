import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baby_monitor/utils/platform_info.dart';
import 'package:baby_monitor/presentation/kid_mode/tv/tv_pin_pad.dart';

void main() {
  setUp(() {
    PlatformInfo.overrideForTest(isTV: true, tvPlatform: TvPlatform.androidTV);
  });

  tearDown(() {
    PlatformInfo.clearTestOverride();
  });

  group('TvPinPad', () {
    testWidgets('renders number buttons 0-9', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvPinPad(
              onSubmit: (_) {},
            ),
          ),
        ),
      );

      for (var i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('renders clear and backspace buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvPinPad(
              onSubmit: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('C'), findsOneWidget); // Clear
      expect(find.text('\u232b'), findsOneWidget); // Backspace
    });

    testWidgets('shows correct number of PIN dots', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvPinPad(
              pinLength: 4,
              onSubmit: (_) {},
            ),
          ),
        ),
      );

      // 4 Container widgets for the PIN dots
      final dotContainers = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(dotContainers, findsNWidgets(4));
    });

    testWidgets('shows title when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvPinPad(
              title: 'Enter PIN',
              onSubmit: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Enter PIN'), findsOneWidget);
    });

    testWidgets('shows cancel button when onCancel is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvPinPad(
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
