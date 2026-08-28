import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/core/models/user_role.dart';
import 'package:fluter_apk/services/users_admin_service.dart';

void main() {
  group('UsersAdminPolicy', () {
    test('blocks self role change', () {
      expect(
        () => UsersAdminPolicy.ensureCanChangeRole(
          actorUserId: 'u1',
          targetUserId: 'u1',
          newRole: UserRole.admin,
          activeSuperAdminCount: 2,
          currentTargetRole: UserRole.voter,
        ),
        throwsA(isA<UsersAdminException>()),
      );
    });

    test('blocks demoting the only active superadmin', () {
      expect(
        () => UsersAdminPolicy.ensureCanChangeRole(
          actorUserId: 'admin-1',
          targetUserId: 'super-1',
          newRole: UserRole.admin,
          activeSuperAdminCount: 1,
          currentTargetRole: UserRole.superadmin,
        ),
        throwsA(isA<UsersAdminException>()),
      );
    });

    test('allows demoting superadmin when another remains active', () {
      expect(
        () => UsersAdminPolicy.ensureCanChangeRole(
          actorUserId: 'admin-1',
          targetUserId: 'super-1',
          newRole: UserRole.admin,
          activeSuperAdminCount: 2,
          currentTargetRole: UserRole.superadmin,
        ),
        returnsNormally,
      );
    });

    test('blocks self deactivation', () {
      expect(
        () => UsersAdminPolicy.ensureCanChangeActive(
          actorUserId: 'u1',
          targetUserId: 'u1',
          newActive: false,
          targetRole: UserRole.superadmin,
          activeSuperAdminCount: 2,
        ),
        throwsA(isA<UsersAdminException>()),
      );
    });

    test('blocks deactivating the only active superadmin', () {
      expect(
        () => UsersAdminPolicy.ensureCanChangeActive(
          actorUserId: 'admin-1',
          targetUserId: 'super-1',
          newActive: false,
          targetRole: UserRole.superadmin,
          activeSuperAdminCount: 1,
        ),
        throwsA(isA<UsersAdminException>()),
      );
    });
  });
}
