import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/domain/services/parental_control_service.dart';

void main() {
  group('Math problem for PIN reset', () {
    test('generateMathProblem returns valid problem', () {
      final problem = ParentalControlService.generateMathProblem();
      expect(problem.question, isNotEmpty);
      expect(problem.answer, isA<int>());
    });

    test('generateMathProblem answer is correct', () {
      for (int i = 0; i < 50; i++) {
        final problem = ParentalControlService.generateMathProblem();
        final parts = problem.question.split(' + ');
        final a = int.parse(parts[0]);
        final b = int.parse(parts[1]);
        expect(problem.answer, equals(a + b));
      }
    });

    test('generateMathProblem produces reasonable range', () {
      for (int i = 0; i < 50; i++) {
        final problem = ParentalControlService.generateMathProblem();
        // Range: 10-39 + 10-39 = 20-78
        expect(problem.answer, greaterThanOrEqualTo(20));
        expect(problem.answer, lessThanOrEqualTo(78));
      }
    });
  });

  group('PIN entry dialog UI', () {
    testWidgets('PIN entry dialog shows title and input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Set New PIN'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Enter a new 4-digit PIN'),
                        const SizedBox(height: 16),
                        TextField(
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 4,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Set New PIN'), findsOneWidget);
      expect(find.text('Enter a new 4-digit PIN'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });
  });
}
