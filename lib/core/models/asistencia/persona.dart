/// Persona/participante (compatible con Firestore personas).
class PersonaAsistencia {
  const PersonaAsistencia({
    required this.id,
    required this.nombres,
    required this.apellidos,
    this.identificador,
    this.codigoQR,
  });

  final String id;
  final String nombres;
  final String apellidos;
  final String? identificador;
  final String? codigoQR;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  factory PersonaAsistencia.fromMap(Map<String, dynamic> map, [String? id]) {
    final docId = id ?? map['id']?.toString() ?? '';
    return PersonaAsistencia(
      id: docId,
      nombres: map['nombres'] as String? ?? '',
      apellidos: map['apellidos'] as String? ?? '',
      identificador: map['identificador'] as String?,
      codigoQR: map['codigoQR'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombres': nombres,
      'apellidos': apellidos,
      'identificador': identificador,
      'codigoQR': codigoQR,
    };
  }
}
