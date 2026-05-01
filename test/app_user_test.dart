import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/core/models/user.dart';
import 'package:fluter_apk/core/models/user_role.dart';

void main() {
  group('AppUser memberId', () {
    test('serializes and reads canonical memberId', () {
      const user = AppUser(
        id: 'uid-1',
        email: 'socio@example.com',
        role: UserRole.voter,
        employeeNumber: 'W-001',
        memberId: 'member-1',
        createdAt: 1,
      );

      final map = user.toMap();
      final parsed = AppUser.fromMap(map, user.id);

      expect(map['memberId'], 'member-1');
      expect(parsed.memberId, 'member-1');
      expect(parsed.employeeNumber, 'W-001');
      expect(parsed.role, UserRole.voter);
    });
  });
}
