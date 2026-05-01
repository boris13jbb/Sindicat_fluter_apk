import '../core/models/asistencia/asistencia.dart';
import '../core/models/asistencia/registro_asistencia_result.dart';

/// Contrato mínimo para registrar asistencia desde el escáner.
///
/// Se usa para inyección en UI y facilitar pruebas sin inicializar Firebase.
abstract class AsistenciaRegistroApi {
  Stream<List<EventoAsistencia>> getAllEventos();

  Future<Map<String, int>> sincronizarMiembrosConPersonas();

  Future<RegistroAsistenciaResult> registrarAsistenciaDesdeEscaneo(
    String codigoEscaneado,
    String eventoId,
    MetodoRegistro metodo, {
    bool registrosAttendanceEvents = false,
  });
}

