import 'evento.dart';
import 'persona.dart';

/// Método de registro de asistencia.
enum MetodoRegistro {
  escaneoQr('ESCANEO_QR'),
  escaneoBarcode('ESCANEO_BARCODE'),
  manual('MANUAL');

  const MetodoRegistro(this.value);
  final String value;

  static MetodoRegistro fromString(String v) {
    return MetodoRegistro.values.firstWhere(
      (e) => e.value == v.toUpperCase(),
      orElse: () => MetodoRegistro.manual,
    );
  }
}

/// Registro de asistencia (compatible con Firestore asistencias).
class AsistenciaRegistro {
  const AsistenciaRegistro({
    required this.id,
    required this.eventoId,
    required this.personaId,
    this.fechaRegistro,
    this.metodoRegistro = MetodoRegistro.manual,
    this.justificacion,
    this.asistio = true,
  });

  final String id;
  final String eventoId;
  final String personaId;
  final int? fechaRegistro;
  final MetodoRegistro metodoRegistro;
  final String? justificacion;
  final bool asistio;

  factory AsistenciaRegistro.fromMap(Map<String, dynamic> map, [String? id]) {
    final docId = id ?? map['id']?.toString() ?? '';
    return AsistenciaRegistro(
      id: docId,
      eventoId: (map['eventoId'] ?? '').toString(),
      personaId: (map['personaId'] ?? '').toString(),
      fechaRegistro: (map['fechaRegistro'] as num?)?.toInt(),
      metodoRegistro: MetodoRegistro.fromString(
        (map['metodoRegistro'] as String?) ?? 'MANUAL',
      ),
      justificacion: map['justificacion'] as String?,
      asistio: map['asistio'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': id,
      'eventoId': eventoId,
      'personaId': personaId,
      'fechaRegistro': fechaRegistro ?? now,
      'horaRegistro': fechaRegistro ?? now,
      'metodoRegistro': metodoRegistro.value,
      'justificacion': justificacion ?? '',
      'asistio': asistio,
    };
  }
}

/// Asistencia con datos de persona y evento para la UI.
class AsistenciaConDatos {
  const AsistenciaConDatos({
    required this.asistencia,
    required this.persona,
    required this.evento,
  });

  final AsistenciaRegistro asistencia;
  final PersonaAsistencia persona;
  final EventoAsistencia evento;
}
