import 'package:flutter_test/flutter_test.dart';
import 'package:fluter_apk/core/models/election.dart';
import 'package:fluter_apk/core/models/user_role.dart';
import 'package:fluter_apk/core/security/election_visibility.dart';

void main() {
  final now = DateTime(2026, 5, 1, 12);

  Election election({
    bool isActive = true,
    bool isVisibleToVoters = true,
    bool showResultsAutomatically = true,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Election(
      id: 'election-1',
      title: 'Elección test',
      description: '',
      startDate: (startDate ?? now.subtract(const Duration(days: 2)))
          .millisecondsSinceEpoch,
      endDate: (endDate ?? now.subtract(const Duration(hours: 1)))
          .millisecondsSinceEpoch,
      isActive: isActive,
      isVisibleToVoters: isVisibleToVoters,
      showResultsAutomatically: showResultsAutomatically,
      createdBy: 'admin',
    );
  }

  group('canViewElectionResults', () {
    test('always allows admin roles for administrative review', () {
      final hiddenDraft = election(
        isActive: false,
        isVisibleToVoters: false,
        showResultsAutomatically: false,
        endDate: now.add(const Duration(days: 1)),
      );

      expect(
        canViewElectionResults(
          election: hiddenDraft,
          viewerRole: UserRole.admin,
          now: now,
        ),
        isTrue,
      );
      expect(
        canViewElectionResults(
          election: hiddenDraft,
          viewerRole: UserRole.superadmin,
          now: now,
        ),
        isTrue,
      );
    });

    test(
      'allows voters only after an active visible automatic election ends',
      () {
        expect(
          canViewElectionResults(
            election: election(),
            viewerRole: UserRole.voter,
            now: now,
          ),
          isTrue,
        );
      },
    );

    test('denies voters before the election ends', () {
      expect(
        canViewElectionResults(
          election: election(endDate: now.add(const Duration(minutes: 1))),
          viewerRole: UserRole.voter,
          now: now,
        ),
        isFalse,
      );
    });

    test('denies voters when automatic publishing is disabled', () {
      expect(
        canViewElectionResults(
          election: election(showResultsAutomatically: false),
          viewerRole: UserRole.voter,
          now: now,
        ),
        isFalse,
      );
    });

    test('denies voters when election is inactive or hidden', () {
      expect(
        canViewElectionResults(
          election: election(isActive: false),
          viewerRole: UserRole.voter,
          now: now,
        ),
        isFalse,
      );
      expect(
        canViewElectionResults(
          election: election(isVisibleToVoters: false),
          viewerRole: UserRole.voter,
          now: now,
        ),
        isFalse,
      );
    });
  });
}
