import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/core/models/member.dart';
import 'package:fluter_apk/core/models/user_role.dart';
import 'package:fluter_apk/core/security/voter_member_policy.dart';
import 'package:fluter_apk/services/users_admin_service.dart';

void main() {
  group('VoterMemberPolicy.ensureCanLinkMember', () {
    test('case 1: allows VOTER + active member', () {
      expect(
        () => VoterMemberPolicy.ensureCanLinkMember(
          targetRole: UserRole.voter,
          memberStatus: MemberStatus.active,
          memberId: 'member-1',
          targetUserId: 'user-1',
        ),
        returnsNormally,
      );
    });

    test('case 2: rejects VOTER + inactive member', () {
      expect(
        () => VoterMemberPolicy.ensureCanLinkMember(
          targetRole: UserRole.voter,
          memberStatus: MemberStatus.inactive,
          memberId: 'member-1',
          targetUserId: 'user-1',
        ),
        throwsA(
          isA<VoterMemberPolicyException>().having(
            (error) => error.message,
            'message',
            contains('inactivo'),
          ),
        ),
      );
    });

    test('case 3: rejects member already linked to another user', () {
      expect(
        () => VoterMemberPolicy.ensureCanLinkMember(
          targetRole: UserRole.voter,
          memberStatus: MemberStatus.active,
          memberId: 'member-1',
          existingOwnerUserId: 'other-user',
          targetUserId: 'user-1',
        ),
        throwsA(isA<VoterMemberPolicyException>()),
      );
    });

    test('case 10: allows ADMIN + inactive member', () {
      expect(
        () => VoterMemberPolicy.ensureCanLinkMember(
          targetRole: UserRole.admin,
          memberStatus: MemberStatus.inactive,
          memberId: 'member-1',
          targetUserId: 'admin-1',
        ),
        returnsNormally,
      );
    });

    test('case 9: does not mutate member status on link validation', () {
      const status = MemberStatus.inactive;
      expect(
        () => VoterMemberPolicy.ensureCanLinkMember(
          targetRole: UserRole.voter,
          memberStatus: status,
          memberId: 'member-1',
          targetUserId: 'user-1',
        ),
        throwsA(isA<VoterMemberPolicyException>()),
      );
      expect(status, MemberStatus.inactive);
    });
  });

  group('VoterMemberPolicy.evaluateElectionEligibility', () {
    test('case 4: requireAttendance=false + active member is eligible', () {
      expect(
        VoterMemberPolicy.evaluateElectionEligibility(
          memberExists: true,
          memberStatus: MemberStatus.active,
          requireAttendance: false,
          hasAttendance: false,
        ),
        isTrue,
      );
    });

    test(
      'case 5: requireAttendance=false + inactive member is not eligible',
      () {
        expect(
          VoterMemberPolicy.evaluateElectionEligibility(
            memberExists: true,
            memberStatus: MemberStatus.inactive,
            requireAttendance: false,
            hasAttendance: false,
          ),
          isFalse,
        );
      },
    );

    test(
      'case 6: requireAttendance=true + inactive member is not eligible',
      () {
        expect(
          VoterMemberPolicy.evaluateElectionEligibility(
            memberExists: true,
            memberStatus: MemberStatus.inactive,
            requireAttendance: true,
            hasAttendance: true,
          ),
          isFalse,
        );
      },
    );

    test('case 7: missing member is not eligible', () {
      expect(
        VoterMemberPolicy.evaluateElectionEligibility(
          memberExists: false,
          memberStatus: null,
          requireAttendance: false,
          hasAttendance: false,
        ),
        isFalse,
      );
    });

    test('case 8: active member without attendance when required', () {
      expect(
        VoterMemberPolicy.evaluateElectionEligibility(
          memberExists: true,
          memberStatus: MemberStatus.active,
          requireAttendance: true,
          hasAttendance: false,
        ),
        isFalse,
      );
    });
  });

  group('UsersAdminPolicy.ensureCanLinkMember', () {
    test('wraps VoterMemberPolicyException as UsersAdminException', () {
      expect(
        () => UsersAdminPolicy.ensureCanLinkMember(
          targetRole: UserRole.voter,
          memberStatus: MemberStatus.inactive,
          memberId: 'member-1',
          targetUserId: 'user-1',
        ),
        throwsA(isA<UsersAdminException>()),
      );
    });
  });
}
