import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import '../core/models/asistencia/evento.dart';
import '../core/models/asistencia/persona.dart';
import '../core/models/asistencia/asistencia.dart';
import 'auth_service.dart';

/// Servicio de asistencia con Firestore (compatible con module-asistencia Android).
class AsistenciaService {
  AsistenciaService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _eventos = 'eventos';
  static const String _personas = 'personas';
  static const String _asistencias = 'asistencias';

  // ---------- Eventos ----------
  Stream<List<EventoAsistencia>> getAllEventos() {
    return _firestore
        .collection(_eventos)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => EventoAsistencia.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Future<EventoAsistencia?> getEventoById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _firestore.collection(_eventos).doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return EventoAsistencia.fromMap(doc.data()!, doc.id);
  }

  Future<String> createEvento(EventoAsistencia evento) async {
    final ref = evento.id.isEmpty
        ? _firestore.collection(_eventos).doc()
        : _firestore.collection(_eventos).doc(evento.id);
    final id = ref.id;
    final data = evento.toMap()..['id'] = id;
    if (evento.fechaCreacion == null) {
      data['fechaCreacion'] = DateTime.now().millisecondsSinceEpoch;
    }
    await ref.set(data);
    return id;
  }

  Future<void> updateEvento(EventoAsistencia evento) async {
    if (evento.id.isEmpty) return;
    await _firestore.collection(_eventos).doc(evento.id).update({
      'nombre': evento.nombre,
      'fecha': evento.fecha,
      'tipoReunion': evento.tipoReunion.value,
      'descripcion': evento.descripcion ?? '',
    });
  }

  Future<void> deleteEvento(String eventoId) async {
    if (eventoId.isEmpty) return;
    await _firestore.collection(_eventos).doc(eventoId).delete();
  }

  // ---------- Personas ----------
  Stream<List<PersonaAsistencia>> getAllPersonas() {
    return _firestore
        .collection(_personas)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PersonaAsistencia.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Future<PersonaAsistencia?> getPersonaById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _firestore.collection(_personas).doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return PersonaAsistencia.fromMap(doc.data()!, doc.id);
  }

  Future<PersonaAsistencia?> getPersonaPorIdentificador(
    String identificador,
  ) async {
    if (identificador.isEmpty) return null;
    final snap = await _firestore
        .collection(_personas)
        .where('identificador', isEqualTo: identificador)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return PersonaAsistencia.fromMap(d.data(), d.id);
  }

  Future<PersonaAsistencia?> getPersonaPorQR(String codigoQR) async {
    if (codigoQR.isEmpty) return null;
    final snap = await _firestore
        .collection(_personas)
        .where('codigoQR', isEqualTo: codigoQR)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return PersonaAsistencia.fromMap(d.data(), d.id);
  }

  Future<String> createPersona(PersonaAsistencia persona) async {
    final ref = _firestore.collection(_personas).doc();
    final id = ref.id;
    final data = persona.toMap()..['id'] = id;
    await ref.set(data);
    return id;
  }

  Future<void> updatePersona(PersonaAsistencia persona) async {
    if (persona.id.isEmpty) return;
    await _firestore
        .collection(_personas)
        .doc(persona.id)
        .update(persona.toMap());
  }

  Future<void> deletePersona(String personaId) async {
    if (personaId.isEmpty) return;
    await _firestore.collection(_personas).doc(personaId).delete();
  }

  // ---------- Asistencias ----------
  Stream<List<AsistenciaConDatos>> getAsistenciasPorEventoStream(
    String eventoId,
  ) {
    return _firestore
        .collection(_asistencias)
        .where('eventoId', isEqualTo: eventoId)
        .snapshots()
        .asyncExpand(
          (snap) => Stream.fromFuture(_buildAsistenciasConDatos(snap.docs)),
        );
  }

  Future<List<AsistenciaConDatos>> getAllAsistenciasConDatos() async {
    final snap = await _firestore.collection(_asistencias).get();
    return await _buildAsistenciasConDatos(snap.docs);
  }

  Future<List<AsistenciaConDatos>> _buildAsistenciasConDatos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final list = <AsistenciaConDatos>[];
    for (final d in docs) {
      final a = AsistenciaRegistro.fromMap(d.data(), d.id);
      final evento = await getEventoById(a.eventoId);
      final persona = await getPersonaById(a.personaId);
      if (evento != null && persona != null) {
        list.add(
          AsistenciaConDatos(asistencia: a, persona: persona, evento: evento),
        );
      }
    }
    return list;
  }

  Future<String> createAsistencia(
    AsistenciaRegistro asistencia,
    String identificadorPersona,
  ) async {
    final ref = _firestore.collection(_asistencias).doc();
    final id = ref.id;
    final data = asistencia.toMap()
      ..['id'] = id
      ..['personaId'] = identificadorPersona;
    await ref.set(data);
    // Compatibilidad con subcolección
    await _firestore
        .collection(_eventos)
        .doc(asistencia.eventoId)
        .collection(_asistencias)
        .doc(id)
        .set(data);
    return id;
  }

  Future<AsistenciaRegistro?> getAsistenciaPorEventoYPersona(
    String eventoId,
    String personaId,
  ) async {
    final snap = await _firestore
        .collection(_asistencias)
        .where('eventoId', isEqualTo: eventoId)
        .where('personaId', isEqualTo: personaId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return AsistenciaRegistro.fromMap(
      snap.docs.first.data(),
      snap.docs.first.id,
    );
  }

  /// Verifica si el usuario actual ha registrado su asistencia para un evento específico.
  Future<bool> isUserRegisteredInEvent(
    String eventoId,
    String? userId,
    String? userEmail,
  ) async {
    if (eventoId.isEmpty) return false;

    // 1. Obtener datos completos del usuario para tener su número de empleado
    final fullUser = await AuthService().getCurrentUser();
    final employeeNum = fullUser?.employeeNumber;

    // Lista de posibles identificadores del usuario
    final idsParaProbar = {
      if (userId != null && userId.isNotEmpty) userId,
      if (userEmail != null && userEmail.isNotEmpty) userEmail,
      if (employeeNum != null && employeeNum.isNotEmpty) employeeNum,
    };

    for (final id in idsParaProbar) {
      // Buscar si existe una persona con este identificador
      final persona = await getPersonaPorIdentificador(id);
      if (persona != null) {
        final a = await getAsistenciaPorEventoYPersona(eventoId, persona.id);
        if (a != null) return true;
      }
    }
    return false;
  }

  Future<String?> registrarAsistenciaDesdeEscaneo(
    String codigoEscaneado,
    String eventoId,
    MetodoRegistro metodo,
  ) async {
    final personaData = parseQRCode(codigoEscaneado);
    var persona = await getPersonaPorQR(codigoEscaneado);
    if (persona == null && personaData?.identificador != null) {
      persona = await getPersonaPorIdentificador(personaData!.identificador!);
    }
    if (persona == null) {
      final id = await createPersona(
        PersonaAsistencia(
          id: '',
          nombres: personaData?.nombres ?? 'Sin nombre',
          apellidos: personaData?.apellidos ?? 'Sin apellido',
          identificador: personaData?.identificador,
          codigoQR: codigoEscaneado,
        ),
      );
      persona = await getPersonaById(id);
    }
    if (persona == null) return null;
    final existente = await getAsistenciaPorEventoYPersona(
      eventoId,
      persona.id,
    );
    if (existente != null) return null;
    return createAsistencia(
      AsistenciaRegistro(
        id: '',
        eventoId: eventoId,
        personaId: persona.id,
        metodoRegistro: metodo,
      ),
      persona.id,
    );
  }

  /// Registro manual de asistencia (compatible con Android)
  Future<String?> registrarAsistenciaManual(
    String identificadorPersona,
    String eventoId,
    bool asistio,
    String justificacion,
  ) async {
    var persona = await getPersonaPorIdentificador(identificadorPersona);
    if (persona == null) {
      // Crear nueva persona si no existe
      final id = await createPersona(
        PersonaAsistencia(
          id: '',
          nombres: identificadorPersona, // Se puede editar después
          apellidos: '',
          identificador: identificadorPersona,
        ),
      );
      persona = await getPersonaById(id);
    }
    if (persona == null) return null;

    final existente = await getAsistenciaPorEventoYPersona(
      eventoId,
      persona.id,
    );
    if (existente != null) return null;

    return createAsistencia(
      AsistenciaRegistro(
        id: '',
        eventoId: eventoId,
        personaId: persona.id,
        asistio: asistio,
        justificacion: justificacion.isEmpty ? null : justificacion,
        metodoRegistro: MetodoRegistro.manual,
      ),
      persona.id,
    );
  }

  /// Eliminar registro de asistencia
  Future<void> deleteAsistencia(String asistenciaId) async {
    if (asistenciaId.isEmpty) return;
    await _firestore.collection(_asistencias).doc(asistenciaId).delete();
  }

  static PersonaData? parseQRCode(String codigo) {
    if (codigo.startsWith('{')) {
      /* lógica JSON */
    }
    final partes = codigo.split(',');
    if (partes.length >= 3) {
      return PersonaData(
        nombres: partes[0],
        apellidos: partes[1],
        identificador: partes[2],
      );
    }
    return PersonaData(identificador: codigo);
  }

  // ---------- Exportación ----------

  /// Genera archivo Excel (CSV) con todas las asistencias
  Future<Uint8List> generateExcelExport(
    List<AsistenciaConDatos> asistencias,
  ) async {
    final sb = StringBuffer();
    // Encabezados
    sb.writeln('Evento,Fecha Evento,Persona,Asistió,Fecha Registro,Método');

    // Datos
    for (final a in asistencias) {
      final fechaEvento = DateTime.fromMillisecondsSinceEpoch(a.evento.fecha);
      final fechaRegistro = a.asistencia.fechaRegistro != null
          ? DateTime.fromMillisecondsSinceEpoch(a.asistencia.fechaRegistro!)
          : null;

      sb.writeln(
        '"${a.evento.nombre}",'
        '"${fechaEvento.day}/${fechaEvento.month}/${fechaEvento.year}",'
        '"${a.persona.nombreCompleto}",'
        '${a.asistencia.asistio ? 'Sí' : 'No'},'
        '"${fechaRegistro != null ? '${fechaRegistro.day}/${fechaRegistro.month}/${fechaRegistro.year} ${fechaRegistro.hour.toString().padLeft(2, '0')}:${fechaRegistro.minute.toString().padLeft(2, '0')}' : ''}",'
        '"${a.asistencia.metodoRegistro.value}"',
      );
    }

    return Uint8List.fromList(sb.toString().codeUnits);
  }

  /// Genera PDF con reporte de asistencias
  Future<Uint8List> generatePDFExport(
    List<AsistenciaConDatos> asistencias,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Reporte de Asistencias',
                style: pw.TextStyle(fontSize: 20),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                // Encabezados de tabla
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Evento',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Persona',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Asistió',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Método',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                // Datos
                ...asistencias.map(
                  (a) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(a.evento.nombre),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(a.persona.nombreCompleto),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(a.asistencia.asistio ? 'Sí' : 'No'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(a.asistencia.metodoRegistro.value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Total de registros: ${asistencias.length}',
              style: pw.TextStyle(fontSize: 12),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}

class PersonaData {
  PersonaData({this.nombres = '', this.apellidos = '', this.identificador});
  final String nombres;
  final String apellidos;
  final String? identificador;
}
