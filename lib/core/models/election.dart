/// Estado persistido de una elección en Firestore.
///
/// `isActive` se mantiene como bandera operativa histórica. Este estado evita
/// que una elección activa se guarde como `DRAFT` en integraciones/reportes.
enum ElectionStatus {
  draft('DRAFT'),
  active('ACTIVE'),
  closed('CLOSED');

  const ElectionStatus(this.firestoreValue);

  final String firestoreValue;

  static ElectionStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'ACTIVE':
      case 'ACTIVA':
        return ElectionStatus.active;
      case 'CLOSED':
      case 'FINALIZED':
      case 'FINALIZADA':
      case 'FINISHED':
        return ElectionStatus.closed;
      case 'DRAFT':
      case 'BORRADOR':
      default:
        return ElectionStatus.draft;
    }
  }
}

String? validateElectionDateRange({
  required DateTime? startDate,
  required DateTime? endDate,
  Duration minimumDuration = const Duration(minutes: 1),
}) {
  if (startDate == null || endDate == null) {
    return 'Selecciona fechas de inicio y fin';
  }
  if (!endDate.isAfter(startDate)) {
    return 'La fecha de fin debe ser posterior al inicio';
  }
  if (endDate.difference(startDate) < minimumDuration) {
    return 'La elección debe durar al menos 1 minuto';
  }
  return null;
}

String? validateElectionTimestampRange({
  required int startDate,
  required int endDate,
  Duration minimumDuration = const Duration(minutes: 1),
}) {
  return validateElectionDateRange(
    startDate: DateTime.fromMillisecondsSinceEpoch(startDate),
    endDate: DateTime.fromMillisecondsSinceEpoch(endDate),
    minimumDuration: minimumDuration,
  );
}

/// Elección (compatible con Firestore elections).
class Election {
  const Election({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.isActive = false,
    this.isVisibleToVoters = true,
    this.showResultsAutomatically = true,
    this.requireAttendance = false,
    this.eventoAsistenciaId,
    this.createdAt,
    required this.createdBy,
    this.totalVotes = 0,
    this.status = ElectionStatus.draft,
  });

  final String id;
  final String title;
  final String description;
  final int startDate;
  final int endDate;
  final bool isActive;
  final bool isVisibleToVoters;
  final bool showResultsAutomatically;
  final bool requireAttendance;
  final String? eventoAsistenciaId;
  final int? createdAt;
  final String createdBy;
  final int totalVotes;
  final ElectionStatus status;

  bool isCurrentlyActive() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return isActive && now >= startDate && now <= endDate;
  }

  bool get isEnded => DateTime.now().millisecondsSinceEpoch > endDate;
  bool get isNotStarted => DateTime.now().millisecondsSinceEpoch < startDate;

  ElectionStatus effectiveStatus({DateTime? now}) {
    if (!isActive) return ElectionStatus.draft;
    final currentTime = (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (currentTime > endDate) return ElectionStatus.closed;
    return ElectionStatus.active;
  }

  factory Election.fromMap(Map<String, dynamic> map, [String? id]) {
    final docId = id ?? map['id'] as String? ?? '';
    return Election(
      id: docId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      startDate: (map['startDate'] as num?)?.toInt() ?? 0,
      endDate: (map['endDate'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? false,
      isVisibleToVoters: map['isVisibleToVoters'] as bool? ?? true,
      showResultsAutomatically:
          map['showResultsAutomatically'] as bool? ?? true,
      requireAttendance: map['requireAttendance'] as bool? ?? false,
      eventoAsistenciaId: map['eventoAsistenciaId'] as String?,
      createdAt: (map['createdAt'] as num?)?.toInt(),
      createdBy: map['createdBy'] as String? ?? '',
      totalVotes: (map['totalVotes'] as num?)?.toInt() ?? 0,
      status: ElectionStatus.fromString(map['status'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': id,
      'title': title,
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'isActive': isActive,
      'isVisibleToVoters': isVisibleToVoters,
      'showResultsAutomatically': showResultsAutomatically,
      'requireAttendance': requireAttendance,
      if (eventoAsistenciaId != null) 'eventoAsistenciaId': eventoAsistenciaId!,
      'createdAt': createdAt ?? now,
      'updatedAt': now,
      'createdBy': createdBy,
      'totalVotes': totalVotes,
      'status': effectiveStatus().firestoreValue,
      'version': 1,
    };
  }

  Election copyWith({
    String? id,
    String? title,
    String? description,
    int? startDate,
    int? endDate,
    bool? isActive,
    bool? isVisibleToVoters,
    bool? showResultsAutomatically,
    bool? requireAttendance,
    String? eventoAsistenciaId,
    int? createdAt,
    String? createdBy,
    int? totalVotes,
    ElectionStatus? status,
  }) {
    return Election(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      isVisibleToVoters: isVisibleToVoters ?? this.isVisibleToVoters,
      showResultsAutomatically:
          showResultsAutomatically ?? this.showResultsAutomatically,
      requireAttendance: requireAttendance ?? this.requireAttendance,
      eventoAsistenciaId: eventoAsistenciaId ?? this.eventoAsistenciaId,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      totalVotes: totalVotes ?? this.totalVotes,
      status: status ?? this.status,
    );
  }
}
