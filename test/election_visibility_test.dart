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

  group('canVoteInElection', () {
    Election votableElection({
      bool isActive = true,
      bool isVisibleToVoters = true,
      DateTime? startDate,
      DateTime? endDate,
    }) {
      return election(
        isActive: isActive,
        isVisibleToVoters: isVisibleToVoters,
        startDate: startDate ?? now.subtract(const Duration(minutes: 10)),
        endDate: endDate ?? now.add(const Duration(minutes: 10)),
      );
    }

    test('allows voting only when active, visible and inside date range', () {
      expect(canVoteInElection(election: votableElection(), now: now), isTrue);
    });

    test('blocks inactive and hidden elections even inside date range', () {
      expect(
        getElectionVotingStatus(
          election: votableElection(isActive: false),
          now: now,
        ),
        ElectionVotingStatus.inactive,
      );
      expect(
        getElectionVotingStatus(
          election: votableElection(isVisibleToVoters: false),
          now: now,
        ),
        ElectionVotingStatus.hidden,
      );
    });

    test('blocks elections outside the voting window', () {
      expect(
        getElectionVotingStatus(
          election: votableElection(
            startDate: now.add(const Duration(minutes: 1)),
          ),
          now: now,
        ),
        ElectionVotingStatus.notStarted,
      );
      expect(
        getElectionVotingStatus(
          election: votableElection(
            endDate: now.subtract(const Duration(minutes: 1)),
          ),
          now: now,
        ),
        ElectionVotingStatus.ended,
      );
    });

    test('archived blocks voting even if schedule would be open', () {
      final openWindow = election(
        startDate: now.subtract(const Duration(minutes: 10)),
        endDate: now.add(const Duration(minutes: 10)),
      ).copyWith(isArchived: true);

      expect(canVoteInElection(election: openWindow, now: now), isFalse);
      expect(
        getElectionVotingStatus(election: openWindow, now: now),
        ElectionVotingStatus.archived,
      );
      expect(
        electionVotingStatusMessage(ElectionVotingStatus.archived),
        contains('archivada'),
      );
    });

    test('archived hides results from voters but not from admins', () {
      final archived = election().copyWith(isArchived: true);
      expect(
        canViewElectionResults(
          election: archived,
          viewerRole: UserRole.voter,
          now: now,
        ),
        isFalse,
      );
      expect(
        canViewElectionResults(
          election: archived,
          viewerRole: UserRole.admin,
          now: now,
        ),
        isTrue,
      );
    });
  });
}
