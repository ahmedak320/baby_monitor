import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/domain/services/parental_control_service.dart';

void main() {
  group('ParentalControlService', () {
    test('hashPin produces consistent hash for same input', () {
      final hash1 = ParentalControlService.hashPin('1234');
      final hash2 = ParentalControlService.hashPin('1234');
      expect(hash1, equals(hash2));
    });

    test('hashPin produces different hash for different input', () {
      final hash1 = ParentalControlService.hashPin('1234');
      final hash2 = ParentalControlService.hashPin('5678');
      expect(hash1, isNot(equals(hash2)));
    });

    test('hashPin produces SHA-256 length output', () {
      final hash = ParentalControlService.hashPin('1234');
      // SHA-256 produces 64 hex characters
      expect(hash.length, equals(64));
    });

    test('generateMathProblem produces valid problem', () {
      final problem = ParentalControlService.generateMathProblem();
      expect(problem.question, contains('+'));
      expect(problem.answer, greaterThanOrEqualTo(20)); // min: 10+10
      expect(problem.answer, lessThanOrEqualTo(78)); // max: 39+39
    });

    test('generateMathProblem answer matches question', () {
      for (int i = 0; i < 100; i++) {
        final problem = ParentalControlService.generateMathProblem();
        final parts = problem.question.split(' + ');
        final a = int.parse(parts[0]);
        final b = int.parse(parts[1]);
        expect(problem.answer, equals(a + b));
      }
    });
  });
}
