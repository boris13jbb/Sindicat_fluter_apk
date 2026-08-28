import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/core/security/account_status.dart';

void main() {
  group('VoteEligibilityPolicy.memberIdRequiredMessage', () {
    test('allows vote without memberId when attendance is not required', () {
      expect(
        VoteEligibilityPolicy.memberIdRequiredMessage(
          requireAttendance: false,
          memberId: null,
        ),
        isNull,
      );
    });

    test('blocks vote when attendance is required and memberId is missing', () {
      final message = VoteEligibilityPolicy.memberIdRequiredMessage(
        requireAttendance: true,
        memberId: null,
      );

      expect(message, isNotNull);
      expect(message, contains('padrón'));
    });

    test('blocks vote when attendance is required and memberId is blank', () {
      final message = VoteEligibilityPolicy.memberIdRequiredMessage(
        requireAttendance: true,
        memberId: '   ',
      );

      expect(message, isNotNull);
    });

    test('allows vote when attendance is required and memberId exists', () {
      expect(
        VoteEligibilityPolicy.memberIdRequiredMessage(
          requireAttendance: true,
          memberId: 'member-1',
        ),
        isNull,
      );
    });
  });
}
