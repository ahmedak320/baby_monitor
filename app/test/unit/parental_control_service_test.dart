import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/domain/services/parental_control_service.dart';
import 'package:baby_monitor/utils/pbkdf2.dart';

void main() {
  group('ParentalControlService', () {
    test('hashPin produces consistent hash for same input and salt', () {
      final salt = Pbkdf2.fromHex('00112233445566778899aabbccddeeff');
      final hash1 = ParentalControlService.hashPin('1234', salt);
      final hash2 = ParentalControlService.hashPin('1234', salt);
      expect(hash1, equals(hash2));
    });

    test('hashPin produces different hash for different input', () {
      final salt = Pbkdf2.fromHex('00112233445566778899aabbccddeeff');
      final hash1 = ParentalControlService.hashPin('1234', salt);
      final hash2 = ParentalControlService.hashPin('5678', salt);
      expect(hash1, isNot(equals(hash2)));
    });

    test('hashPin produces different hash for different salt', () {
      final salt1 = Pbkdf2.fromHex('00112233445566778899aabbccddeeff');
      final salt2 = Pbkdf2.fromHex('ffeeddccbbaa99887766554433221100');
      final hash1 = ParentalControlService.hashPin('1234', salt1);
      final hash2 = ParentalControlService.hashPin('1234', salt2);
      expect(hash1, isNot(equals(hash2)));
    });

    test('hashPin produces 64 hex character output (32 bytes)', () {
      final salt = Pbkdf2.fromHex('00112233445566778899aabbccddeeff');
      final hash = ParentalControlService.hashPin('1234', salt);
      // PBKDF2 with keyLength=32 produces 64 hex characters
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
