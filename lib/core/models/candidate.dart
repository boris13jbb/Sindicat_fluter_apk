String? validateCandidateImageUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return 'Ingresa una URL http(s) válida';
  }
  return null;
}

String? validateCandidateOrder(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;

  final order = int.tryParse(trimmed);
  if (order == null) return 'Ingresa un número entero';
  if (order < 0) return 'El orden no puede ser negativo';
  return null;
}

int parseCandidateOrder(String? value) {
  return int.tryParse(value?.trim() ?? '') ?? 0;
}

const candidateWithVotesDeletionError =
    'No se puede eliminar un candidato con votos registrados';

String? validateCandidateDeletion({
  required int voteCount,
  bool hasVoteDocuments = false,
}) {
  if (voteCount > 0 || hasVoteDocuments) {
    return candidateWithVotesDeletionError;
  }
  return null;
}

String candidateNameKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool hasCandidateNameConflict({
  required Candidate candidate,
  required Iterable<Candidate> existingCandidates,
}) {
  final key = candidateNameKey(candidate.name);
  if (key.isEmpty) return false;

  return existingCandidates.any((existing) {
    if (existing.electionId != candidate.electionId) return false;
    if (existing.id.isNotEmpty && existing.id == candidate.id) return false;
    return candidateNameKey(existing.name) == key;
  });
}

/// Candidato de una elección (compatible con subcolección candidates).
class Candidate {
  const Candidate({
    required this.id,
    required this.electionId,
    required this.name,
    this.description,
    this.imageUrl,
    this.order = 0,
    this.voteCount = 0,
  });

  final String id;
  final String electionId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int order;
  final int voteCount;

  factory Candidate.fromMap(Map<String, dynamic> map, [String? id]) {
    final docId = id ?? map['id'] as String? ?? '';
    // Debug: Ensure electionId is properly extracted
    final electionId = map['electionId'] as String? ?? '';
    return Candidate(
      id: docId,
      electionId: electionId,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      imageUrl: map['imageUrl'] as String?,
      order: (map['order'] as num?)?.toInt() ?? 0,
      voteCount: (map['voteCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'electionId': electionId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'order': order,
      'voteCount': voteCount,
      'nameKey': candidateNameKey(name),
    };
  }

  Candidate copyWith({
    String? id,
    String? electionId,
    String? name,
    String? description,
    String? imageUrl,
    int? order,
    int? voteCount,
  }) {
    return Candidate(
      id: id ?? this.id,
      electionId: electionId ?? this.electionId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      order: order ?? this.order,
      voteCount: voteCount ?? this.voteCount,
    );
  }
}
