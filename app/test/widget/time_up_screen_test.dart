import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/presentation/kid_mode/screens/time_up_screen.dart';
import 'package:baby_monitor/presentation/kid_mode/screens/bedtime_screen.dart';

void main() {
  group('TimeUpScreen', () {
    testWidgets('displays time up message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TimeUpScreen(onParentOverride: () {})),
      );

      expect(find.text('All done for today!'), findsOneWidget);
      expect(find.text('Parent? Tap here'), findsOneWidget);
    });

    testWidgets('parent tap triggers parental gate', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TimeUpScreen(onParentOverride: () {})),
      );

      await tester.tap(find.text('Parent? Tap here'));
      await tester.pumpAndSettle();

      // Parental gate dialog should appear
      expect(find.text('Parent Verification'), findsOneWidget);
    });

    testWidgets('parental gate uses provided childAge for difficulty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: TimeUpScreen(childAge: 12, onParentOverride: () {})),
      );

      await tester.tap(find.text('Parent? Tap here'));
      await tester.pumpAndSettle();

      // With age 12, should show multiplication problem
      final problemFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('= ?'),
      );
      expect(problemFinder, findsOneWidget);
      final problemText = (tester.widget(problemFinder) as Text).data!;
      expect(problemText, contains('\u00d7'));
    });
  });

  group('BedtimeScreen', () {
    testWidgets('displays bedtime message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BedtimeScreen(onParentOverride: () {})),
      );

      expect(find.text('Time for bed!'), findsOneWidget);
      expect(find.text('Parent? Tap here'), findsOneWidget);
    });

    testWidgets('parental gate uses provided childAge for difficulty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BedtimeScreen(childAge: 10, onParentOverride: () {})),
      );

      await tester.tap(find.text('Parent? Tap here'));
      await tester.pumpAndSettle();

      // With age 10, should show multiplication problem
      final problemFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('= ?'),
      );
      expect(problemFinder, findsOneWidget);
      final problemText = (tester.widget(problemFinder) as Text).data!;
      expect(problemText, contains('\u00d7'));
    });

    testWidgets('default childAge is 5 (addition)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BedtimeScreen(onParentOverride: () {})),
      );

      await tester.tap(find.text('Parent? Tap here'));
      await tester.pumpAndSettle();

      final problemFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('= ?'),
      );
      final problemText = (tester.widget(problemFinder) as Text).data!;
      // Default age 5 should use addition
      expect(problemText, contains('+'));
    });
  });
}
