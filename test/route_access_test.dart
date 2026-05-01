import 'package:flutter_test/flutter_test.dart';
import 'package:fluter_apk/core/models/user.dart';
import 'package:fluter_apk/core/models/user_role.dart';
import 'package:fluter_apk/core/security/route_access.dart';

void main() {
  AppUser userWithRole(UserRole role) {
    return AppUser(
      id: role.value,
      email: '${role.value}@test.local',
      role: role,
    );
  }

  group('resolveProtectedRouteAccess', () {
    test('returns loading while auth provider is still initializing', () {
      final decision = resolveProtectedRouteAccess(
        isLoading: true,
        isSignedIn: false,
        user: null,
      );

      expect(decision, RouteAccessDecision.loading);
    });

    test('requires login when there is no signed in user', () {
      final decision = resolveProtectedRouteAccess(
        isLoading: false,
        isSignedIn: false,
        user: null,
      );

      expect(decision, RouteAccessDecision.loginRequired);
    });

    test('allows any authenticated role when route only requires auth', () {
      for (final role in UserRole.values) {
        final decision = resolveProtectedRouteAccess(
          isLoading: false,
          isSignedIn: true,
          user: userWithRole(role),
        );

        expect(decision, RouteAccessDecision.allowed, reason: role.value);
      }
    });

    test('allows only superadmin and admin in admin routes', () {
      final expected = {
        UserRole.superadmin: RouteAccessDecision.allowed,
        UserRole.admin: RouteAccessDecision.allowed,
        UserRole.operadorAsistencia: RouteAccessDecision.denied,
        UserRole.voter: RouteAccessDecision.denied,
        UserRole.user: RouteAccessDecision.denied,
      };

      for (final entry in expected.entries) {
        final decision = resolveProtectedRouteAccess(
          isLoading: false,
          isSignedIn: true,
          user: userWithRole(entry.key),
          allowedRoles: adminRouteRoles,
        );

        expect(decision, entry.value, reason: entry.key.value);
      }
    });

    test('allows asistencia only to admins and attendance operators', () {
      final expected = {
        UserRole.superadmin: RouteAccessDecision.allowed,
        UserRole.admin: RouteAccessDecision.allowed,
        UserRole.operadorAsistencia: RouteAccessDecision.allowed,
        UserRole.voter: RouteAccessDecision.denied,
        UserRole.user: RouteAccessDecision.denied,
      };

      for (final entry in expected.entries) {
        final decision = resolveProtectedRouteAccess(
          isLoading: false,
          isSignedIn: true,
          user: userWithRole(entry.key),
          allowedRoles: attendanceRouteRoles,
        );

        expect(decision, entry.value, reason: entry.key.value);
      }
    });
  });
}
