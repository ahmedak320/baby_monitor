import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/presentation/kid_mode/widgets/parental_gate.dart';

void main() {
  group('ParentalGate', () {
    // Reset static state before each test
    setUp(() {
      // We can't directly reset private statics, but we can test observable
      // behavior. The widget creates fresh instances but shares static state.
    });

    testWidgets('displays math problem and input field', (tester) async {
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

      // Should show the dialog title
      expect(find.text('Parent Verification'), findsOneWidget);
      expect(find.text('Solve this to continue:'), findsOneWidget);

      // Should show Submit and Cancel buttons
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Should have an input field
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('correct answer returns true', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showParentalGate(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Extract the math problem from the displayed text
      // The problem format is "$_num1 $_operation $_num2 = ?"
      final problemFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('= ?'),
      );
      expect(problemFinder, findsOneWidget);

      final problemText = (tester.widget(problemFinder) as Text).data!;
      // Parse: "X + Y = ?" or "X × Y = ?"
      final cleaned = problemText.replaceAll('= ?', '').trim();
      int answer;
      if (cleaned.contains('\u00d7')) {
        final parts = cleaned.split('\u00d7');
        answer = int.parse(parts[0].trim()) * int.parse(parts[1].trim());
      } else {
        final parts = cleaned.split('+');
        answer = int.parse(parts[0].trim()) + int.parse(parts[1].trim());
      }

      // Enter the correct answer
      await tester.enterText(find.byType(TextField), answer.toString());
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('wrong answer shows error and decrements attempts', (
      tester,
    ) async {
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

      // Enter a wrong answer
      await tester.enterText(find.byType(TextField), '99999');
      await tester.tap(find.text('Submit'));
      await tester.pump();

      // Should show error with remaining attempts
      expect(find.textContaining('attempts remaining'), findsOneWidget);
    });

    testWidgets('cancel returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showParentalGate(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('age 5 generates addition problems', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showParentalGate(context, childAge: 5),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final problemFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('= ?'),
      );
      final problemText = (tester.widget(problemFinder) as Text).data!;

      // Age 5 should use addition (+), not multiplication (×)
      expect(problemText, contains('+'));
      expect(problemText, isNot(contains('\u00d7')));
    });

    testWidgets('age 10+ generates multiplication problems', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showParentalGate(context, childAge: 12),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final problemFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('= ?'),
      );
      final problemText = (tester.widget(problemFinder) as Text).data!;

      // Age 10+ should use multiplication (×)
      expect(problemText, contains('\u00d7'));
    });

    testWidgets('age 8 generates three-digit addition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showParentalGate(context, childAge: 8),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final problemFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('= ?'),
      );
      final problemText = (tester.widget(problemFinder) as Text).data!;

      // Age 7-9 should use addition with 3-digit numbers
      expect(problemText, contains('+'));
      // Extract numbers and verify they're 3 digits (100-499)
      final cleaned = problemText.replaceAll('= ?', '').trim();
      final parts = cleaned.split('+');
      final a = int.parse(parts[0].trim());
      final b = int.parse(parts[1].trim());
      expect(a, greaterThanOrEqualTo(100));
      expect(b, greaterThanOrEqualTo(100));
    });
  });
}
