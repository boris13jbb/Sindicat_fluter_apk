import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../core/models/asistencia/asistencia.dart';
import '../core/models/member.dart';
import '../core/reports/attendance_report_generator.dart';
import '../core/utils/qr_encoding_helper.dart';
import 'auth_service.dart';
import 'members_service.dart';
import 'attendance_service.dart';

/// Servicio de asistencia con Firestore (compatible con module-asistencia Android).
class AsistenciaService {
  AsistenciaService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Getter público para acceso desde UI (solo lectura)
  FirebaseFirestore get firestore => _firestore;

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
      if (evento.modalidad != null) 'modalidad': evento.modalidad!.value,
    });
  }

  /// Actualiza la modalidad de un evento y actualiza automáticamente
  /// las justificaciones de las asistencias existentes.
  Future<void> updateEventoModalidad(
    String eventoId,
    Modalidad nuevaModalidad,
  ) async {
    if (eventoId.isEmpty) return;

    // 1. Actualizar modalidad en el evento
    await _firestore.collection(_eventos).doc(eventoId).update({
      'modalidad': nuevaModalidad.value,
    });

    // 2. Generar justificación automática basada en la modalidad
    final justificacion = JustificacionHelper.obtenerJustificacion(
      nuevaModalidad,
    );

    // 3. Actualizar todas las asistencias del evento con la nueva justificación
    final asistenciasSnap = await _firestore
        .collection(_asistencias)
        .where('eventoId', isEqualTo: eventoId)
        .get();

    for (final doc in asistenciasSnap.docs) {
      await doc.reference.update({'justificacion': justificacion});
    }

    // 4. Actualizar también en subcolecciones si existen
    final subColeccionSnap = await _firestore
        .collection(_eventos)
        .doc(eventoId)
        .collection(_asistencias)
        .get();

    for (final doc in subColeccionSnap.docs) {
      await doc.reference.update({'justificacion': justificacion});
    }
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
  /// PRIORIDAD: workerCode (Número de Trabajador) como identificador principal
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
    // PRIORIDAD: employeeNumber (workerCode) primero
    final idsParaProbar = <String>[];
    if (employeeNum != null && employeeNum.isNotEmpty) {
      idsParaProbar.add(employeeNum);
    }
    if (userId != null && userId.isNotEmpty) {
      idsParaProbar.add(userId);
    }
    if (userEmail != null && userEmail.isNotEmpty) {
      idsParaProbar.add(userEmail);
    }

    // Buscar en miembros (members) primero por workerCode
    final membersService = MembersService();
    for (final workerCode in idsParaProbar) {
      final member = await membersService.getMemberByWorkerCode(workerCode);
      if (member != null) {
        debugPrint('✅ Miembro encontrado por workerCode: ${member.workerCode}');
        // Verificar si este miembro tiene asistencia registrada en el evento
        final persona = await getPersonaPorIdentificador(member.workerCode!);
        if (persona != null) {
          final a = await getAsistenciaPorEventoYPersona(eventoId, persona.id);
          if (a != null) return true;
        }
      }
    }

    // Fallback: buscar en colección personas legacy
    for (final id in idsParaProbar) {
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

  /// Servicio de miembros para lookup por workerCode
  final MembersService _membersService = MembersService();

  /// Si [registrosAttendanceEvents] es `true`, escribe en
  /// `attendance_events/{eventoId}/asistencias`; en ese modo [personaId] debe corresponder al id del doc en **`members`**.
  Future<String?> registrarAsistenciaDesdeEscaneo(
    String codigoEscaneado,
    String eventoId,
    MetodoRegistro metodo, {
    bool registrosAttendanceEvents = false,
  }) async {
    debugPrint('📱 ========== INICIO REGISTRO ASISTENCIA ==========');
    debugPrint('📱 Código escaneado: "$codigoEscaneado"');
    debugPrint('📱 Evento ID: $eventoId');
    debugPrint('📱 Método: ${metodo.value}');

    // Parsear código QR para extraer identificador
    final personaData = parseQRCode(codigoEscaneado);

    debugPrint('🔍 DATOS PARSEADOS DEL QR:');
    if (personaData != null) {
      debugPrint('   - Nombres: "${personaData.nombres}"');
      debugPrint('   - Apellidos: "${personaData.apellidos}"');
      debugPrint('   - Identificador: "${personaData.identificador}"');
    } else {
      debugPrint('   ⚠️ No se pudieron parsear datos del QR');
    }

    // PRIORIDAD 1: Buscar en members collection por workerCode (si hay identificador)
    Member? memberEncontrado;
    if (personaData?.identificador != null &&
        personaData!.identificador!.isNotEmpty) {
      debugPrint('🔍 BUSQUEDA EN MEMBERS:');
      debugPrint(
        '   🔍 Buscando miembro por workerCode: "${personaData.identificador}"',
      );
      memberEncontrado = await _membersService.getMemberByWorkerCode(
        personaData.identificador!,
      );

      if (memberEncontrado != null) {
        debugPrint('   ✅ MIEMBRO ENCONTRADO:');
        debugPrint('      - ID: ${memberEncontrado.id}');
        debugPrint('      - firstName: "${memberEncontrado.firstName}"');
        debugPrint('      - lastName: "${memberEncontrado.lastName}"');
        debugPrint('      - fullName: "${memberEncontrado.fullName}"');
        debugPrint('      - workerCode: "${memberEncontrado.workerCode}"');
        debugPrint('      - documentId: "${memberEncontrado.documentId}"');
        debugPrint('      - memberNumber: "${memberEncontrado.memberNumber}"');
      } else {
        debugPrint(
          '   ❌ No se encontró miembro con workerCode: "${personaData.identificador}"',
        );
      }
    }

    // Si encontramos el miembro, asegurar que exista en collection personas con datos correctos
    PersonaAsistencia? persona;
    if (memberEncontrado != null) {
      // Usar workerCode como identificador principal
      final identificador = memberEncontrado.workerCode?.isNotEmpty == true
          ? memberEncontrado.workerCode!
          : memberEncontrado.documentId ?? '';

      debugPrint('🔍 PROCESAMIENTO DE MIEMBRO:');
      debugPrint('   📌 Identificador a usar: "$identificador"');
      debugPrint('   📌 Nombres del miembro: "${memberEncontrado.firstName}"');
      debugPrint('   📌 Apellidos del miembro: "${memberEncontrado.lastName}"');

      if (identificador.isNotEmpty) {
        // Buscar persona existente por identificador
        persona = await getPersonaPorIdentificador(identificador);

        // Si no existe, crearla con datos del miembro
        if (persona == null) {
          debugPrint('   🆕 Persona no existe, creando desde miembro...');

          // 🔍 VALIDACIÓN CRÍTICA: Asegurar que los nombres no estén vacíos
          final nombresValidos =
              memberEncontrado.firstName.isNotEmpty &&
              memberEncontrado.firstName != 'Sin nombre';
          final apellidosValidos =
              memberEncontrado.lastName.isNotEmpty &&
              memberEncontrado.lastName != 'Sin apellido';

          debugPrint('   🔎 VALIDACIÓN DE DATOS DEL MIEMBRO:');
          debugPrint(
            '      - firstName válido: $nombresValidos ("${memberEncontrado.firstName}")',
          );
          debugPrint(
            '      - lastName válido: $apellidosValidos ("${memberEncontrado.lastName}")',
          );

          if (!nombresValidos || !apellidosValidos) {
            debugPrint('   ⚠️ ADVERTENCIA: Datos del miembro incompletos');
            debugPrint(
              '      - Usando fallback: fullName="${memberEncontrado.fullName}"',
            );
          }

          final nuevaPersona = PersonaAsistencia(
            id: '',
            nombres: nombresValidos
                ? memberEncontrado.firstName
                : (memberEncontrado.fullName.isNotEmpty
                      ? memberEncontrado.fullName.split(' ').first
                      : 'Sin nombre'),
            apellidos: apellidosValidos
                ? memberEncontrado.lastName
                : (memberEncontrado.fullName.isNotEmpty
                      ? memberEncontrado.fullName.split(' ').skip(1).join(' ')
                      : 'Sin apellido'),
            identificador: identificador,
            codigoQR: codigoEscaneado,
          );

          debugPrint('   📝 Datos de nueva persona:');
          debugPrint('      - nombres: "${nuevaPersona.nombres}"');
          debugPrint('      - apellidos: "${nuevaPersona.apellidos}"');
          debugPrint('      - identificador: "${nuevaPersona.identificador}"');
          debugPrint(
            '      - nombreCompleto resultante: "${nuevaPersona.nombreCompleto}"',
          );

          final id = await createPersona(nuevaPersona);
          persona = await getPersonaById(id);

          if (persona != null) {
            debugPrint('   ✅ Persona creada exitosamente:');
            debugPrint('      - ID: $id');
            debugPrint('      - nombreCompleto: "${persona.nombreCompleto}"');
            debugPrint('      - identificador: "${persona.identificador}"');
          } else {
            debugPrint(
              '   ❌ ERROR: No se pudo recuperar la persona recién creada',
            );
          }
        } else {
          debugPrint('   📋 Persona ya existe en colección personas:');
          debugPrint('      - ID: ${persona.id}');
          debugPrint('      - nombres: "${persona.nombres}"');
          debugPrint('      - apellidos: "${persona.apellidos}"');
          debugPrint('      - identificador: "${persona.identificador}"');

          // 🔍 CRÍTICO: Verificar si los datos están vacíos o son incorrectos y actualizarlos
          final tieneDatosVacios =
              persona.nombres.isEmpty ||
              persona.nombres == 'Sin nombre' ||
              persona.apellidos.isEmpty ||
              persona.apellidos == 'Sin apellido';
          final nombresDiferentes =
              persona.nombres != memberEncontrado.firstName ||
              persona.apellidos != memberEncontrado.lastName;

          debugPrint('   🔎 VERIFICACIÓN DE DATOS EXISTENTES:');
          debugPrint('      - ¿Datos vacíos?: $tieneDatosVacios');
          debugPrint('      - ¿Datos diferentes?: $nombresDiferentes');
          debugPrint(
            '      - Persona actual: "${persona.nombres} ${persona.apellidos}"',
          );
          debugPrint(
            '      - Miembro esperado: "${memberEncontrado.firstName} ${memberEncontrado.lastName}"',
          );
          debugPrint(
            '      - Identificador actual: "${persona.identificador}"',
          );
          debugPrint('      - Identificador esperado: "$identificador"');

          if (tieneDatosVacios || nombresDiferentes) {
            debugPrint('   🔄 ACTUALIZANDO DATOS DE PERSONA:');
            debugPrint(
              '      - Antes: "${persona.nombres} ${persona.apellidos}"',
            );
            debugPrint(
              '      - Después: "${memberEncontrado.firstName} ${memberEncontrado.lastName}"',
            );

            final personaActualizada = PersonaAsistencia(
              id: persona.id,
              nombres: memberEncontrado.firstName,
              apellidos: memberEncontrado.lastName,
              identificador: identificador,
              codigoQR: persona.codigoQR ?? codigoEscaneado,
            );
            await updatePersona(personaActualizada);
            persona = personaActualizada;
            debugPrint(
              '   ✅ Persona actualizada: "${persona.nombreCompleto}" (ID: ${persona.identificador})',
            );
          } else {
            debugPrint(
              '   ✅ Datos de persona están correctos, no se necesita actualización',
            );
          }
        }
      } else {
        debugPrint('   ⚠️ ADVERTENCIA: Identificador vacío para miembro');
      }
    } else {
      debugPrint('   ⚠️ No se encontró miembro en colección members');
    }

    // PRIORIDAD 2: Si no es miembro o no se encontró, buscar por código QR exacto
    if (persona == null) {
      persona = await getPersonaPorQR(codigoEscaneado);
      if (persona != null) {
        debugPrint(
          '   ✅ Persona encontrada por código QR exacto: ${persona.nombreCompleto}',
        );
      }
    }

    // PRIORIDAD 3: Buscar por identificador del QR parseado
    if (persona == null &&
        personaData?.identificador != null &&
        personaData!.identificador!.isNotEmpty) {
      debugPrint(
        '   🔍 Buscando por identificador (fallback): ${personaData.identificador}',
      );
      persona = await getPersonaPorIdentificador(personaData.identificador!);
      if (persona != null) {
        debugPrint(
          '   ✅ Persona encontrada por identificador: ${persona.nombreCompleto}',
        );
      }
    }

    // PRIORIDAD 4: Si aún no se encuentra, crear nueva persona
    if (persona == null) {
      debugPrint('🆍 CREANDO NUEVA PERSONA (no es miembro):');
      final nombres = personaData?.nombres ?? '';
      final apellidos = personaData?.apellidos ?? '';
      final identificador = personaData?.identificador ?? '';

      debugPrint('   📝 Datos del QR parseado:');
      debugPrint('      - Nombres: "$nombres"');
      debugPrint('      - Apellidos: "$apellidos"');
      debugPrint('      - Identificador: "$identificador"');

      if (nombres.isEmpty && apellidos.isEmpty && identificador.isEmpty) {
        debugPrint('   ❌ ERROR: QR vacío o sin datos válidos');
        throw Exception(
          'El código QR no contiene datos válidos. Asegúrate de usar el formato: {"nombres":"...","apellidos":"...","identificador":"..."}',
        );
      }

      final nuevaPersona = PersonaAsistencia(
        id: '',
        nombres: nombres.isNotEmpty ? nombres : 'Sin nombre',
        apellidos: apellidos.isNotEmpty ? apellidos : 'Sin apellido',
        identificador: identificador,
        codigoQR: codigoEscaneado,
      );

      debugPrint('   📝 Creando persona con datos:');
      debugPrint('      - nombres: "${nuevaPersona.nombres}"');
      debugPrint('      - apellidos: "${nuevaPersona.apellidos}"');
      debugPrint('      - identificador: "${nuevaPersona.identificador}"');

      final id = await createPersona(nuevaPersona);
      persona = await getPersonaById(id);

      if (persona != null) {
        debugPrint(
          '   ✅ Nueva persona creada: "${persona.nombreCompleto}" (ID: $id, Identificador: ${persona.identificador})',
        );
      }
    }

    if (persona == null) {
      debugPrint('   ❌ ERROR: No se pudo crear/encontrar persona');
      return null;
    }

    if (registrosAttendanceEvents) {
      final attendanceApi = AttendanceService();
      final personaIdFirestore = memberEncontrado?.id ??
          await _memberFirestoreIdParaReporteAttendance(persona);
      if (personaIdFirestore == null || personaIdFirestore.isEmpty) {
        debugPrint(
          '   ❌ Evento tipo reporte: el código no coincide con un socio activo '
          '(id en collection members). Confirme padrón o QR del socio.',
        );
        return null;
      }
      if (await attendanceApi.hasAttendanceRecord(
        eventoId,
        personaIdFirestore,
      )) {
        debugPrint(
          '   ⚠️ Esta persona ya tiene registro en este evento (`attendance_events`).',
        );
        return null;
      }
      return attendanceApi.registerAttendance(
        eventId: eventoId,
        personaId: personaIdFirestore,
        asistio: true,
        metodo: metodo,
      );
    }

    // Verificar duplicado de asistencia
    final existente = await getAsistenciaPorEventoYPersona(
      eventoId,
      persona.id,
    );
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
    debugPrint(
      '   📋 Datos registrados - Nombre: ${persona.nombreCompleto}, Identificador: ${persona.identificador}',
    );
    debugPrint('📱 ========== RESUMEN FINAL ==========');
    debugPrint('   📊 Persona final:');
    debugPrint('      - ID: ${persona.id}');
    debugPrint('      - nombres: "${persona.nombres}"');
    debugPrint('      - apellidos: "${persona.apellidos}"');
    debugPrint('      - identificador: "${persona.identificador}"');
    debugPrint('      - nombreCompleto: "${persona.nombreCompleto}"');
    debugPrint('   📊 Registro de asistencia:');
    debugPrint('      - eventoId: $eventoId');
    debugPrint('      - metodoRegistro: ${metodo.value}');
    debugPrint('=========================================\n');

    return asistenciaId;
  }

  Future<String?> _memberFirestoreIdParaReporteAttendance(
    PersonaAsistencia persona,
  ) async {
    final raw = persona.identificador?.trim();
    if (raw != null && raw.isNotEmpty) {
      Member? m = await _membersService.getMemberByWorkerCode(raw);
      m ??= await _membersService.getMemberByNumber(raw);
      m ??= await _membersService.getMemberByDocument(raw);
      if (m != null) return m.id;
    }
    final porDocId = await _membersService.getMemberById(persona.id);
    return porDocId?.id;
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

  // ========== SINCRONIZACIÓN AUTOMÁTICA ==========

  /// Sincroniza automáticamente todos los miembros de la colección 'members'
  /// hacia la colección legacy 'personas' para compatibilidad con el módulo de asistencia.
  ///
  /// Este método asegura que:
  /// 1. Los miembros importados estén disponibles en las listas de selección de asistencia
  /// 2. El escáner pueda reconocer sus códigos QR
  /// 3. No se requiera exportación/importación manual entre módulos
  Future<Map<String, int>> sincronizarMiembrosConPersonas() async {
    try {
      debugPrint(
        '🔄 Iniciando sincronización automática members → personas...',
      );

      int sincronizados = 0;
      int omitidos = 0;
      int errores = 0;

      // Obtener todos los miembros activos
      final snapshot = await _firestore
          .collection('members')
          .where('status', isEqualTo: 'active')
          .get();

      debugPrint('   📊 Encontrados ${snapshot.docs.length} miembros activos');

      for (final doc in snapshot.docs) {
        try {
          final member = Member.fromMap(doc.data(), doc.id);

          // Usar workerCode como identificador principal, fallback a documentId
          final identificador = member.workerCode?.isNotEmpty == true
              ? member.workerCode!
              : (member.documentId?.isNotEmpty == true
                    ? member.documentId!
                    : null);

          if (identificador == null || identificador.isEmpty) {
            debugPrint(
              '   ⚠️ Omitido: ${member.fullName} no tiene workerCode ni documentId',
            );
            omitidos++;
            continue;
          }

          // Verificar si ya existe en collection personas
          final personaExistente = await getPersonaPorIdentificador(
            identificador,
          );

          if (personaExistente != null) {
            // Actualizar datos si hay cambios
            final necesitaActualizacion =
                personaExistente.nombres != member.firstName ||
                personaExistente.apellidos != member.lastName ||
                personaExistente.identificador != identificador;

            debugPrint('   🔎 VERIFICANDO SINCRONIZACIÓN:');
            debugPrint(
              '      - Persona actual: "${personaExistente.nombres} ${personaExistente.apellidos}" ($identificador)',
            );
            debugPrint(
              '      - Miembro esperado: "${member.firstName} ${member.lastName}" ($identificador)',
            );
            debugPrint(
              '      - ¿Necesita actualización?: $necesitaActualizacion',
            );

            if (necesitaActualizacion) {
              final personaActualizada = PersonaAsistencia(
                id: personaExistente.id,
                nombres: member.firstName.isNotEmpty
                    ? member.firstName
                    : (member.fullName.isNotEmpty
                          ? member.fullName.split(' ').first
                          : 'Sin nombre'),
                apellidos: member.lastName.isNotEmpty
                    ? member.lastName
                    : (member.fullName.isNotEmpty
                          ? member.fullName.split(' ').skip(1).join(' ')
                          : 'Sin apellido'),
                identificador: identificador,
                codigoQR: QREncodingHelper.generateMemberQRCode(member),
              );

              await updatePersona(personaActualizada);
              debugPrint(
                '   ✏️ Actualizado: ${personaActualizada.nombreCompleto} ($identificador)',
              );
              sincronizados++;
            } else {
              omitidos++; // Ya está sincronizado y actualizado
            }
          } else {
            // Crear nueva persona en colección legacy
            debugPrint('   🆕 Creando nueva persona desde miembro...');
            final nuevaPersona = PersonaAsistencia(
              id: '',
              nombres: member.firstName.isNotEmpty
                  ? member.firstName
                  : (member.fullName.isNotEmpty
                        ? member.fullName.split(' ').first
                        : 'Sin nombre'),
              apellidos: member.lastName.isNotEmpty
                  ? member.lastName
                  : (member.fullName.isNotEmpty
                        ? member.fullName.split(' ').skip(1).join(' ')
                        : 'Sin apellido'),
              identificador: identificador,
              codigoQR: QREncodingHelper.generateMemberQRCode(member),
            );

            debugPrint('      - Nombres: "${nuevaPersona.nombres}"');
            debugPrint('      - Apellidos: "${nuevaPersona.apellidos}"');
            debugPrint(
              '      - Identificador: "${nuevaPersona.identificador}"',
            );

            await createPersona(nuevaPersona);
            debugPrint(
              '   ✅ Creado: ${nuevaPersona.nombreCompleto} ($identificador)',
            );
            sincronizados++;
          }
        } catch (e) {
          debugPrint('   ❌ Error procesando miembro ${doc.id}: $e');
          errores++;
        }
      }

      final resultado = {
        'sincronizados': sincronizados,
        'omitidos': omitidos,
        'errores': errores,
        'total_procesados': snapshot.docs.length,
      };

      debugPrint('✅ Sincronización completada: $resultado');

      return resultado;
    } catch (e) {
      debugPrint('❌ Error en sincronización: $e');
      rethrow;
    }
  }

  /// Escucha cambios en la colección 'members' y sincroniza automáticamente
  /// con 'personas' en tiempo real.
  Stream<Map<String, int>> watchAndSyncMembers() {
    return _firestore.collection('members').snapshots().asyncMap((
      snapshot,
    ) async {
      debugPrint('🔄 Cambio detectado en members, sincronizando...');
      return await sincronizarMiembrosConPersonas();
    });
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

  /// Genera archivo XLSX real con todas las asistencias.
  static Future<Uint8List> generateExcelExportStatic(
    List<AsistenciaConDatos> asistencias,
  ) async {
    final excel = Excel.createExcel();
    const sheetName = 'Asistencias';
    final sheet = excel[sheetName];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Evento'),
      TextCellValue('Fecha Evento'),
      TextCellValue('Persona'),
      TextCellValue('Asistió'),
      TextCellValue('Fecha Registro'),
      TextCellValue('Método'),
    ]);

    for (final a in asistencias) {
      final fechaEvento = DateTime.fromMillisecondsSinceEpoch(a.evento.fecha);
      final fechaRegistro = a.asistencia.fechaRegistro != null
          ? DateTime.fromMillisecondsSinceEpoch(a.asistencia.fechaRegistro!)
          : null;

      sheet.appendRow([
        TextCellValue(a.evento.nombre),
        TextCellValue(
          '${fechaEvento.day}/${fechaEvento.month}/${fechaEvento.year}',
        ),
        TextCellValue(a.persona.nombreCompleto),
        TextCellValue(a.asistencia.asistio ? 'Sí' : 'No'),
        TextCellValue(
          fechaRegistro != null
              ? '${fechaRegistro.day}/${fechaRegistro.month}/${fechaRegistro.year} ${fechaRegistro.hour.toString().padLeft(2, '0')}:${fechaRegistro.minute.toString().padLeft(2, '0')}'
              : '',
        ),
        TextCellValue(a.asistencia.metodoRegistro.value),
      ]);
    }

    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 32);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 24);
    sheet.setColumnWidth(5, 22);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo XLSX');
    }
    return Uint8List.fromList(bytes);
  }

  /// Genera archivo XLSX real con todas las asistencias.
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
