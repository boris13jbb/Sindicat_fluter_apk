/// Resultado de un candidato en una elección.
class ElectionResultItem {
  const ElectionResultItem({
    required this.candidateId,
    required this.candidateName,
    this.candidateImageUrl,
    required this.voteCount,
    this.rank = 0,
  });

  final String candidateId;
  final String candidateName;
  final String? candidateImageUrl;
  final int voteCount;
  final int rank;
}

/// Resultados agregados de una elección.
class ElectionResults {
  const ElectionResults({
    required this.electionId,
    required this.results,
    this.totalVotes = 0,
  });

  final String electionId;
  final List<ElectionResultItem> results;
  final int totalVotes;
}
