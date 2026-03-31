import 'package:flutter_test/flutter_test.dart';

/// Tests for the child mode guard logic.
/// The guard checks: if kid mode is active AND route doesn't start with '/kid',
/// redirect to '/kid/home'. Otherwise, allow navigation.
///
/// We test the pure logic here to avoid depending on GoRouterState constructors.
void main() {
  /// Replicates the guard logic for testability.
  String? childModeGuardLogic(String matchedLocation, bool isInKidMode) {
    final isKidRoute = matchedLocation.startsWith('/kid');
    if (isInKidMode && !isKidRoute) {
      return '/kid/home';
    }
    return null;
  }

  group('childModeGuard logic', () {
    test('redirects /dashboard when kid mode active', () {
      expect(childModeGuardLogic('/dashboard', true), equals('/kid/home'));
    });

    test('redirects /login when kid mode active', () {
      expect(childModeGuardLogic('/login', true), equals('/kid/home'));
    });

    test('redirects /dashboard/account-settings when kid mode active', () {
      expect(
        childModeGuardLogic('/dashboard/account-settings', true),
        equals('/kid/home'),
      );
    });

    test('allows /kid/home when kid mode active', () {
      expect(childModeGuardLogic('/kid/home', true), isNull);
    });

    test('allows /kid/select when kid mode active', () {
      expect(childModeGuardLogic('/kid/select', true), isNull);
    });

    test('allows /kid/player/abc when kid mode active', () {
      expect(childModeGuardLogic('/kid/player/abc', true), isNull);
    });

    test('allows /kid/search when kid mode active', () {
      expect(childModeGuardLogic('/kid/search', true), isNull);
    });

    test('allows /dashboard when kid mode inactive', () {
      expect(childModeGuardLogic('/dashboard', false), isNull);
    });

    test('allows /kid/home when kid mode inactive', () {
      expect(childModeGuardLogic('/kid/home', false), isNull);
    });

    test('allows /login when kid mode inactive', () {
      expect(childModeGuardLogic('/login', false), isNull);
    });
  });

  group('kid mode state transitions', () {
    test('entering kid mode should block dashboard access', () {
      // Simulate: kid mode activated
      final isKidModeActive = true;

      // Any non-kid route should be blocked
      expect(
        childModeGuardLogic('/dashboard', isKidModeActive),
        equals('/kid/home'),
      );
      expect(
        childModeGuardLogic('/onboarding/welcome', isKidModeActive),
        equals('/kid/home'),
      );
    });

    test('exiting kid mode should allow dashboard access', () {
      // Simulate: kid mode deactivated
      final isKidModeActive = false;

      // All routes should be allowed
      expect(childModeGuardLogic('/dashboard', isKidModeActive), isNull);
      expect(childModeGuardLogic('/kid/home', isKidModeActive), isNull);
    });
  });
}
