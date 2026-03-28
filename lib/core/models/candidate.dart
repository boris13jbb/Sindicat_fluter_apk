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
    return Candidate(
      id: docId,
      electionId: map['electionId'] as String? ?? '',
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
