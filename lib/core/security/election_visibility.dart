import '../models/election.dart';
import '../models/user_role.dart';

bool canViewElectionResults({
  required Election election,
  UserRole? viewerRole,
  DateTime? now,
}) {
  if (viewerRole == UserRole.superadmin || viewerRole == UserRole.admin) {
    return true;
  }

  final nowMillis = (now ?? DateTime.now()).millisecondsSinceEpoch;
  return election.isActive &&
      election.isVisibleToVoters &&
      election.showResultsAutomatically &&
      nowMillis > election.endDate;
}

bool hasElectionEnded(Election election, {DateTime? now}) {
  final nowMillis = (now ?? DateTime.now()).millisecondsSinceEpoch;
  return nowMillis > election.endDate;
}
