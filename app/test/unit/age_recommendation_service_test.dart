import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/domain/services/age_recommendation_service.dart';

void main() {
  group('AgeRecommendationService', () {
    test('toddler bracket (0-2) has strictest settings', () {
      final defaults = AgeRecommendationService.getDefaultSensitivity(1);
      expect(defaults['overstimulation'], greaterThanOrEqualTo(8));
      expect(defaults['scariness'], greaterThanOrEqualTo(8));
    });

    test('preschool bracket (3-5) has moderately strict settings', () {
      final defaults = AgeRecommendationService.getDefaultSensitivity(4);
      expect(defaults['overstimulation'], greaterThanOrEqualTo(6));
      expect(defaults['scariness'], greaterThanOrEqualTo(6));
    });

    test('early school bracket (5-8) has moderate settings', () {
      final defaults = AgeRecommendationService.getDefaultSensitivity(7);
      expect(defaults['overstimulation'], greaterThanOrEqualTo(4));
    });

    test('older kids bracket (8-12) has relaxed settings', () {
      final defaults = AgeRecommendationService.getDefaultSensitivity(10);
      expect(defaults['overstimulation'], lessThanOrEqualTo(5));
      expect(defaults['scariness'], lessThanOrEqualTo(5));
    });

    test('all brackets have required keys', () {
      for (final age in [1, 4, 7, 10]) {
        final defaults = AgeRecommendationService.getDefaultSensitivity(age);
        expect(defaults.containsKey('overstimulation'), isTrue);
        expect(defaults.containsKey('scariness'), isTrue);
        expect(defaults.containsKey('brainrot_tolerance'), isTrue);
        expect(defaults.containsKey('language_strictness'), isTrue);
      }
    });

    test('sensitivity values are in 1-10 range', () {
      for (final age in [0, 1, 3, 5, 8, 12]) {
        final defaults = AgeRecommendationService.getDefaultSensitivity(age);
        for (final entry in defaults.entries) {
          expect(entry.value, greaterThanOrEqualTo(1),
              reason: '${entry.key} for age $age should be >= 1');
          expect(entry.value, lessThanOrEqualTo(10),
              reason: '${entry.key} for age $age should be <= 10');
        }
      }
    });
  });
}
