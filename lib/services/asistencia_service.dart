import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../core/models/asistencia/asistencia.dart';
import '../core/reports/attendance_report_generator.dart';
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
        .snapshots(includeMetadataChanges: true)
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
        .snapshots(includeMetadataChanges: true)
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
        .snapshots(includeMetadataChanges: true)
        .asyncExpand(
          (snap) => Stream.fromFuture(_buildAsistenciasConDatos(snap.docs)),
        );
  }

  Future<List<AsistenciaConDatos>> getAllAsistenciasConDatos() async {
    final snap = await _firestore.collection(_asistencias).get();
    return await _buildAsistenciasConDatos(snap.docs);
  }

  /// Lista global de asistencias con datos relacionados, actualizada en tiempo real.
  Stream<List<AsistenciaConDatos>> watchAllAsistenciasConDatos() {
    return _firestore
        .collection(_asistencias)
        .snapshots(includeMetadataChanges: true)
        .asyncMap((snap) => _buildAsistenciasConDatos(snap.docs));
  }

  Future<List<AsistenciaConDatos>> _buildAsistenciasConDatos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return [];

    // Extraer IDs únicos
    final eventoIds = docs
        .map((d) {
          final data = d.data();
          return data['eventoId'] as String?;
        })
        .whereType<String>()
        .toSet()
        .toList();

    final personaIds = docs
        .map((d) {
          final data = d.data();
          return data['personaId'] as String?;
        })
        .whereType<String>()
        .toSet()
        .toList();

    // Cargar todos los eventos y personas en paralelo
    final eventosFutures = eventoIds.map((id) => getEventoById(id));
    final personasFutures = personaIds.map((id) => getPersonaById(id));

    final eventosList = await Future.wait(eventosFutures);
    final personasList = await Future.wait(personasFutures);

    // Crear mapas para búsqueda rápida
    final eventosMap = {
      for (var e in eventosList.whereType<EventoAsistencia>()) e.id: e,
    };
    final personasMap = {
      for (var p in personasList.whereType<PersonaAsistencia>()) p.id: p,
    };

    // Construir lista de asistencias
    final list = <AsistenciaConDatos>[];
    for (final d in docs) {
      final a = AsistenciaRegistro.fromMap(d.data(), d.id);
      final evento = eventosMap[a.eventoId];
      final persona = personasMap[a.personaId];
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

  /// Se emite de nuevo cuando cambian las asistencias del evento (p. ej. el usuario registra asistencia).
  Stream<bool> watchUserRegisteredInEvent(
    String eventoId,
    String? userId,
    String? userEmail,
  ) {
    if (eventoId.isEmpty) return Stream.value(false);
    return _firestore
        .collection(_asistencias)
        .where('eventoId', isEqualTo: eventoId)
        .snapshots(includeMetadataChanges: true)
        .asyncMap((_) => isUserRegisteredInEvent(eventoId, userId, userEmail));
  }

  Future<String?> registrarAsistenciaDesdeEscaneo(
    String codigoEscaneado,
    String eventoId,
    MetodoRegistro metodo,
  ) async {
    debugPrint('📱 Iniciando registro desde escaneo...');
    debugPrint('   Código escaneado: "$codigoEscaneado"');
    debugPrint('   Evento ID: $eventoId');
    
    // Parsear código QR
    final personaData = parseQRCode(codigoEscaneado);
    
    if (personaData != null) {
      debugPrint('   ✅ Persona parseada: ${personaData.nombres} ${personaData.apellidos} (${personaData.identificador})');
    } else {
      debugPrint('   ⚠️ No se pudieron parsear datos del QR');
    }
    
    // Buscar persona por código QR exacto primero
    var persona = await getPersonaPorQR(codigoEscaneado);
    if (persona != null) {
      debugPrint('   ✅ Persona encontrada por código QR exacto: ${persona.nombreCompleto}');
    }
    
    // Si no se encuentra, buscar por identificador
    if (persona == null && personaData?.identificador != null && personaData!.identificador!.isNotEmpty) {
      debugPrint('   🔍 Buscando por identificador: ${personaData.identificador}');
      persona = await getPersonaPorIdentificador(personaData.identificador!);
      if (persona != null) {
        debugPrint('   ✅ Persona encontrada por identificador: ${persona.nombreCompleto}');
      }
    }
    
    // Si aún no se encuentra, crear nueva persona
    if (persona == null) {
      debugPrint('   🆕 Creando nueva persona...');
      final nombres = personaData?.nombres ?? '';
      final apellidos = personaData?.apellidos ?? '';
      final identificador = personaData?.identificador ?? '';
      
      debugPrint('      Nombres: "$nombres"');
      debugPrint('      Apellidos: "$apellidos"');
      debugPrint('      Identificador: "$identificador"');
      
      if (nombres.isEmpty && apellidos.isEmpty && identificador.isEmpty) {
        debugPrint('   ❌ ERROR: QR vacío o sin datos válidos');
        throw Exception('El código QR no contiene datos válidos. Asegúrate de usar el formato: {"nombres":"...","apellidos":"...","identificador":"..."}');
      }
      
      final nuevaPersona = PersonaAsistencia(
        id: '',
        nombres: nombres.isNotEmpty ? nombres : 'Sin nombre',
        apellidos: apellidos.isNotEmpty ? apellidos : 'Sin apellido',
        identificador: identificador,
        codigoQR: codigoEscaneado,
      );
      
      final id = await createPersona(nuevaPersona);
      persona = await getPersonaById(id);
      
      if (persona != null) {
        debugPrint('   ✅ Nueva persona creada: ${persona.nombreCompleto} (ID: $id)');
      }
    }
    
    if (persona == null) {
      debugPrint('   ❌ ERROR: No se pudo crear/encontrar persona');
      return null;
    }
    
    // Verificar duplicado de asistencia
    final existente = await getAsistenciaPorEventoYPersona(eventoId, persona.id);
    if (existente != null) {
      debugPrint('   ⚠️ Ya existe asistencia para esta persona en este evento');
      return null;
    }
    
    // Crear registro de asistencia
    debugPrint('   ✅ Registrando asistencia...');
    final asistenciaId = await createAsistencia(
      AsistenciaRegistro(
        id: '',
        eventoId: eventoId,
        personaId: persona.id,
        metodoRegistro: metodo,
      ),
      persona.id,
    );
    
    debugPrint('   ✅ Asistencia registrada exitosamente! ID: $asistenciaId');
    return asistenciaId;
  }

  /// Registro manual de asistencia (compatible con Android)
  /// identificadorPersona: ID de Firestore de la persona existente
  Future<String?> registrarAsistenciaManual(
    String personaId, // ID de Firestore de la persona
    String eventoId,
    bool asistio,
    String justificacion,
  ) async {
    if (personaId.isEmpty) {
      throw Exception('ID de persona no proporcionado');
    }
    
    // Obtener persona existente
    final persona = await getPersonaById(personaId);
    if (persona == null) {
      throw Exception('Persona no encontrada con ID: $personaId');
    }

    // Verificar duplicado
    final existente = await getAsistenciaPorEventoYPersona(
      eventoId,
      persona.id,
    );
    if (existente != null) return null; // Ya existe, retornar null

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
    if (codigo.trim().isEmpty) return null;
    
    final limpio = codigo.trim();
    
    // Intentar parsear como JSON
    if (limpio.startsWith('{')) {
      try {
        final Map<String, dynamic> jsonMap = jsonDecode(limpio);
        
        final nombres = jsonMap['nombres']?.toString() ?? '';
        final apellidos = jsonMap['apellidos']?.toString() ?? '';
        final identificador = jsonMap['identificador']?.toString() ?? '';
        
        debugPrint('✅ QR parseado exitosamente:');
        debugPrint('   Nombres: $nombres');
        debugPrint('   Apellidos: $apellidos');
        debugPrint('   Identificador: $identificador');
        
        return PersonaData(
          nombres: nombres,
          apellidos: apellidos,
          identificador: identificador,
        );
      } catch (e) {
        debugPrint('❌ Error parseando JSON QR: $e');
        debugPrint('   Código: $limpio');
      }
    }
    
    // Formato CSV: Juan,Pérez,12345
    final partes = limpio.split(',');
    if (partes.length >= 3) {
      return PersonaData(
        nombres: partes[0].trim(),
        apellidos: partes[1].trim(),
        identificador: partes[2].trim(),
      );
    }
    
    // Solo identificador: 12345
    return PersonaData(identificador: limpio);
  }

  // ---------- Exportación ----------

  /// Genera archivo Excel (CSV) con todas las asistencias
  static Future<Uint8List> generateExcelExportStatic(
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

  /// Genera archivo Excel (CSV) con todas las asistencias
  Future<Uint8List> generateExcelExport(
    List<AsistenciaConDatos> asistencias,
  ) async {
    return await generateExcelExportStatic(asistencias);
  }

  /// Genera PDF con reporte profesional de asistencias (static para compute)
  static Future<Uint8List> generatePDFExportStatic(
    List<AsistenciaConDatos> asistencias,
  ) async {
    // Usar el generador profesional de reportes
    final generator = AttendanceReportGenerator(
      asistencias: asistencias,
      evento: null,
    );

    return await generator.generateReport();
  }

  /// Genera PDF con reporte profesional de asistencias
  Future<Uint8List> generatePDFExport(
    List<AsistenciaConDatos> asistencias,
    String? eventoId,
  ) async {
    // Obtener información del evento si está disponible
    EventoAsistencia? evento;
    if (eventoId != null && eventoId.isNotEmpty) {
      evento = await getEventoById(eventoId);
    }

    // Usar el generador profesional de reportes
    final generator = AttendanceReportGenerator(
      asistencias: asistencias,
      evento: evento,
    );

    return await generator.generateReport();
  }
}

class PersonaData {
  PersonaData({this.nombres = '', this.apellidos = '', this.identificador});
  final String nombres;
  final String apellidos;
  final String? identificador;
}
