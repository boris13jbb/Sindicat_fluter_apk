import '../models/election.dart';
import '../models/user_role.dart';

enum ElectionVotingStatus { open, inactive, hidden, notStarted, ended }

ElectionVotingStatus getElectionVotingStatus({
  required Election election,
  DateTime? now,
}) {
  if (!election.isActive) {
    return ElectionVotingStatus.inactive;
  }

  if (!election.isVisibleToVoters) {
    return ElectionVotingStatus.hidden;
  }

  final nowMillis = (now ?? DateTime.now()).millisecondsSinceEpoch;
  if (nowMillis < election.startDate) {
    return ElectionVotingStatus.notStarted;
  }

  if (nowMillis > election.endDate) {
    return ElectionVotingStatus.ended;
  }

  return ElectionVotingStatus.open;
}

bool canVoteInElection({required Election election, DateTime? now}) {
  return getElectionVotingStatus(election: election, now: now) ==
      ElectionVotingStatus.open;
}

String electionVotingStatusMessage(ElectionVotingStatus status) {
  switch (status) {
    case ElectionVotingStatus.open:
      return 'Elección disponible para votar.';
    case ElectionVotingStatus.inactive:
      return 'Esta elección no está activa para recibir votos.';
    case ElectionVotingStatus.hidden:
      return 'Esta elección no está visible para votantes.';
    case ElectionVotingStatus.notStarted:
      return 'Esta elección aún no inicia.';
    case ElectionVotingStatus.ended:
      return 'Esta elección ya ha finalizado.';
  }
}

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
