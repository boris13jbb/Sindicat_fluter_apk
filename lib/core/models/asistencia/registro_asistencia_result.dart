import '../member.dart';

/// Resultado de un registro de asistencia a partir de un escaneo.
///
/// - [asistenciaId] es `null` cuando no se crea el registro (p. ej. duplicado).
/// - [member] puede ser `null` si el QR no corresponde a un socio en `members`.
class RegistroAsistenciaResult {
  const RegistroAsistenciaResult({required this.asistenciaId, this.member});

  final String? asistenciaId;
  final Member? member;

  bool get ok => asistenciaId != null && asistenciaId!.isNotEmpty;
}

