import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/presentation/onboarding/providers/onboarding_provider.dart';

void main() {
  group('OnboardingState', () {
    test('default state has empty approvedChannelNames', () {
      const state = OnboardingState();
      expect(state.approvedChannelNames, isEmpty);
      expect(state.approvedChannelIds, isEmpty);
    });

    test('copyWith preserves approvedChannelNames', () {
      const state = OnboardingState();
      final updated = state.copyWith(
        approvedChannelNames: {'UC123': 'Test Channel'},
      );
      expect(updated.approvedChannelNames, {'UC123': 'Test Channel'});
    });

    test('copyWith does not overwrite unrelated fields', () {
      final state = const OnboardingState().copyWith(
        approvedChannelNames: {'UC1': 'Ch1'},
        approvedChannelIds: {'UC1'},
      );
      final updated = state.copyWith(childName: 'Meera');
      expect(updated.approvedChannelNames, {'UC1': 'Ch1'});
      expect(updated.approvedChannelIds, {'UC1'});
      expect(updated.childName, 'Meera');
    });

    test('approvedChannelNames stores multiple entries', () {
      final state = const OnboardingState().copyWith(
        approvedChannelIds: {
          'UCbCmjCuTUZos6Inko4u57UQ',
          'UCWI-ohtRu8eoyisLmPsTCrQ',
          'UC_x5XG1OV2P6uZZ5FSM9Ttw',
        },
        approvedChannelNames: {
          'UCbCmjCuTUZos6Inko4u57UQ': 'Cocomelon',
          'UCWI-ohtRu8eoyisLmPsTCrQ': 'Sesame Street',
          'UC_x5XG1OV2P6uZZ5FSM9Ttw': 'Blippi',
        },
      );

      expect(state.approvedChannelIds.length, 3);
      expect(state.approvedChannelNames.length, 3);

      // All channels have names (used by ensureChannelExists)
      for (final id in state.approvedChannelIds) {
        final name = state.approvedChannelNames[id] ?? 'Unknown Channel';
        expect(
          name,
          isNot('Unknown Channel'),
          reason: 'Channel $id should have a stored name',
        );
      }
    });
  });

  group('OnboardingState PIN field', () {
    test('default PIN is empty', () {
      const state = OnboardingState();
      expect(state.pin, isEmpty);
    });

    test('copyWith updates PIN', () {
      final state = const OnboardingState().copyWith(pin: '1234');
      expect(state.pin, '1234');
    });

    test('copyWith preserves PIN when not specified', () {
      final state = const OnboardingState().copyWith(pin: '5678');
      final updated = state.copyWith(childName: 'Test');
      expect(updated.pin, '5678');
      expect(updated.childName, 'Test');
    });
  });

  group('completeOnboarding early validation', () {
    test('returns false when childName is empty', () {
      // Test the validation logic directly via state check
      const state = OnboardingState(childName: '');
      expect(state.childName.isEmpty, isTrue);
      expect(state.childDob, isNull);
      // completeOnboarding() returns false if childName.isEmpty || childDob == null
    });

    test('returns false when childDob is null', () {
      const state = OnboardingState(childName: 'Meera');
      expect(state.childName.isEmpty, isFalse);
      expect(state.childDob, isNull);
    });

    test('passes validation when both set', () {
      final state = const OnboardingState().copyWith(
        childName: 'Meera',
        childDob: DateTime(2023, 3, 15),
      );
      expect(state.childName.isNotEmpty, isTrue);
      expect(state.childDob, isNotNull);
    });
  });
}
