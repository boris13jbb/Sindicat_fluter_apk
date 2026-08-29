import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/core/models/member.dart';
import 'package:fluter_apk/core/security/account_status.dart';

void main() {
  group('VoteEligibilityPolicy.memberIdRequiredMessage', () {
    test('blocks vote when memberId is missing', () {
      final message = VoteEligibilityPolicy.memberIdRequiredMessage(
        memberId: null,
      );

      expect(message, isNotNull);
      expect(message, contains('padrón'));
    });

    test('blocks vote when memberId is blank', () {
      final message = VoteEligibilityPolicy.memberIdRequiredMessage(
        memberId: '   ',
      );

      expect(message, isNotNull);
    });

    test('allows vote when memberId exists', () {
      expect(
        VoteEligibilityPolicy.memberIdRequiredMessage(memberId: 'member-1'),
        isNull,
      );
    });
  });

  group('VoteEligibilityPolicy.memberActiveRequiredMessage', () {
    test('blocks when member does not exist', () {
      final message = VoteEligibilityPolicy.memberActiveRequiredMessage(
        memberExists: false,
        memberStatus: null,
      );

      expect(message, isNotNull);
      expect(message, contains('no existe'));
    });

    test('blocks when member is inactive', () {
      final message = VoteEligibilityPolicy.memberActiveRequiredMessage(
        memberExists: true,
        memberStatus: MemberStatus.inactive,
      );

      expect(message, isNotNull);
      expect(message, contains('no está activo'));
    });

    test('allows when member is active', () {
      expect(
        VoteEligibilityPolicy.memberActiveRequiredMessage(
          memberExists: true,
          memberStatus: MemberStatus.active,
        ),
        isNull,
      );
    });
  });
}
