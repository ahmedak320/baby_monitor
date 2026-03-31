import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/presentation/onboarding/screens/pin_setup_screen.dart';

void main() {
  group('PinSetupScreen', () {
    Widget buildTestWidget() {
      return ProviderScope(child: MaterialApp(home: const PinSetupScreen()));
    }

    testWidgets('shows create PIN phase initially', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Create a Parent PIN'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('moves to confirm phase after entering 4-digit PIN', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Confirm your PIN'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('shows error for PIN shorter than 4 digits', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('PIN must be 4 digits'), findsOneWidget);
      // Should still be on create phase
      expect(find.text('Create a Parent PIN'), findsOneWidget);
    });

    testWidgets('mismatch resets to create phase with error', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Enter PIN
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Next'));
      await tester.pump();

      // Enter different PIN to confirm
      await tester.enterText(find.byType(TextField), '5678');
      await tester.tap(find.text('Confirm'));
      await tester.pump();

      // Should be back to create phase with error
      expect(find.text('Create a Parent PIN'), findsOneWidget);
      expect(
        find.text('PINs did not match. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('back button in confirm phase goes to create phase', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Enter PIN to get to confirm phase
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Confirm your PIN'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      // Should be back to create phase
      expect(find.text('Create a Parent PIN'), findsOneWidget);
    });
  });
}
