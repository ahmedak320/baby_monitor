import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/presentation/kid_mode/widgets/parental_gate.dart';

void main() {
  group('ParentalGate widget', () {
    testWidgets('shows lock icon and title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentalGate(
              onPassed: () {},
              onCancelled: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
      expect(find.text('Parent Verification'), findsOneWidget);
      expect(find.text('Solve this to continue:'), findsOneWidget);
    });

    testWidgets('displays a math problem with = ?', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentalGate(
              onPassed: () {},
              onCancelled: () {},
            ),
          ),
        ),
      );

      // Find the problem text
      final problemFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('= ?'),
      );
      expect(problemFinder, findsOneWidget);
    });

    testWidgets('onPassed called when correct answer submitted',
        (tester) async {
      bool passed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentalGate(
              onPassed: () => passed = true,
              onCancelled: () {},
              childAge: 5,
            ),
          ),
        ),
      );

      // Extract correct answer from the displayed problem
      final problemFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('= ?'),
      );
      final problemText = (tester.widget(problemFinder) as Text).data!;
      final cleaned = problemText.replaceAll('= ?', '').trim();
      final parts = cleaned.split('+');
      final answer =
          int.parse(parts[0].trim()) + int.parse(parts[1].trim());

      await tester.enterText(find.byType(TextField), answer.toString());
      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(passed, isTrue);
    });

    testWidgets('onCancelled called when cancel button pressed',
        (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentalGate(
              onPassed: () {},
              onCancelled: () => cancelled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('wrong answer shows error text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentalGate(
              onPassed: () {},
              onCancelled: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(find.textContaining('Incorrect'), findsOneWidget);
    });

    testWidgets('3 wrong answers triggers cooldown message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentalGate(
              onPassed: () {},
              onCancelled: () {},
            ),
          ),
        ),
      );

      // Submit 3 wrong answers
      for (int i = 0; i < 3; i++) {
        await tester.enterText(find.byType(TextField), '0');
        await tester.tap(find.text('Submit'));
        await tester.pump();
      }

      // After 3 wrong attempts, should show cooldown message
      expect(find.textContaining('Wait 30 seconds'), findsOneWidget);
    });

    testWidgets('child age 5 uses addition operator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentalGate(
              onPassed: () {},
              onCancelled: () {},
              childAge: 5,
            ),
          ),
        ),
      );

      final problemFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('= ?'),
      );
      final problemText = (tester.widget(problemFinder) as Text).data!;
      expect(problemText, contains('+'));
    });

    testWidgets('child age 12 uses multiplication operator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentalGate(
              onPassed: () {},
              onCancelled: () {},
              childAge: 12,
            ),
          ),
        ),
      );

      final problemFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('= ?'),
      );
      final problemText = (tester.widget(problemFinder) as Text).data!;
      expect(problemText, contains('\u00d7'));
    });
  });

  group('showParentalGate', () {
    testWidgets('dialog is not dismissible by tapping outside',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showParentalGate(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dialog should be visible
      expect(find.text('Parent Verification'), findsOneWidget);

      // Tap outside the dialog (barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dialog should still be visible (barrierDismissible: false)
      expect(find.text('Parent Verification'), findsOneWidget);
    });
  });
}
