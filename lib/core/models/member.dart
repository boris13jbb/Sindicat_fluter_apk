/// Estado del socio en el sistema
enum MemberStatus {
  active('Activo'),
  inactive('Inactivo');

  const MemberStatus(this.displayName);

  final String displayName;

  static MemberStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
      case 'activo':
        return MemberStatus.active;
      case 'inactive':
      case 'inactivo':
        return MemberStatus.inactive;
      default:
        return MemberStatus.active;
    }
  }
}

/// Modelo de datos para socios/miembros de la organización
class Member {
  final String id;
  final String memberNumber; // Número de socio (único)
  final String firstName; // Nombres
  final String lastName; // Apellidos
  final String fullName; // Nombre completo (calculado)
  final String? workerCode; // Código/Número de trabajador (identificación interna)
  final String? documentId; // Cédula/DNI (documento oficial)
  final String? email;
  final String? phone;
  final MemberStatus status; // activo, inactivo
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy; // UID de quien lo creó
  final Map<String, dynamic>? additionalData; // Campos personalizados

  Member({
    required this.id,
    required this.memberNumber,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.workerCode,
    this.documentId,
    this.email,
    this.phone,
    this.status = MemberStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.additionalData,
  });

  /// Crear instancia desde mapa de Firestore
  factory Member.fromMap(Map<String, dynamic> map, String id) {
    return Member(
      id: id,
      memberNumber: map['memberNumber'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      fullName: map['fullName'] ?? '',
      workerCode: map['workerCode'],
      documentId: map['documentId'],
      email: map['email'],
      phone: map['phone'],
      status: MemberStatus.fromString(map['status'] ?? 'active'),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : DateTime.now(),
      createdBy: map['createdBy'],
      additionalData: map['additionalData'],
    );
  }

  /// Convertir a mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'memberNumber': memberNumber,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      if (workerCode != null) 'workerCode': workerCode,
      if (documentId != null) 'documentId': documentId,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'status': status.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      if (createdBy != null) 'createdBy': createdBy,
      if (additionalData != null) 'additionalData': additionalData,
    };
  }

  /// Crear copia con cambios
  Member copyWith({
    String? id,
    String? memberNumber,
    String? firstName,
    String? lastName,
    String? fullName,
    String? workerCode,
    String? documentId,
    String? email,
    String? phone,
    MemberStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? additionalData,
  }) {
    return Member(
      id: id ?? this.id,
      memberNumber: memberNumber ?? this.memberNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      workerCode: workerCode ?? this.workerCode,
      documentId: documentId ?? this.documentId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  @override
  String toString() {
    return 'Member(id: $id, memberNumber: $memberNumber, fullName: $fullName, status: $status)';
  }
}
