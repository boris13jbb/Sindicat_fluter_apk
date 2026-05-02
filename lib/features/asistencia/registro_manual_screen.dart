import 'package:flutter/material.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/models/member.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';
import '../../services/members_service.dart';
import '../../services/attendance_service.dart';

/// Registro contra **`eventos/{id}`** histórico **o** `attendance_events/{id}` actual.
class RegistroManualScreen extends StatefulWidget {
  const RegistroManualScreen({super.key, this.evento, this.attendanceEventId});

  /// Modo legacy: documento colección **`eventos`**.
  final EventoAsistencia? evento;

  /// Modo nuevo: doc **`attendance_events`** (solo socios enlazados a `members`).
  final String? attendanceEventId;

  @override
  State<RegistroManualScreen> createState() => _RegistroManualScreenState();
}

class _RegistroManualScreenState extends State<RegistroManualScreen> {
  final _service = AsistenciaService();
  final _membersService = MembersService();
  final _attendanceService = AttendanceService();

  String? _personaIdSeleccionada; // Usar ID en lugar de objeto para Dropdown
  PersonaAsistencia? _personaObj;
  bool _asistio = true;
  final _justificacionController = TextEditingController();
  bool _usarNueva = false;

  /// `member` cuando la fila proviene del padrón sincronizado; `persona` si es legacy solo `personas`.
  String _personaSource = 'member';
  AttendanceEvent? _attendanceEventCached;

  bool get _esModoAttendanceNuevo =>
      widget.attendanceEventId != null && widget.attendanceEventId!.isNotEmpty;

  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _identificadorController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (_esModoAttendanceNuevo) {
      assert(
        widget.evento == null,
        'Use solo attendanceEventId o evento legacy, no ambos.',
      );
      _usarNueva = false;
      _cargarAttendanceEventDoc();
    } else if (widget.evento == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Configuración de evento inválida')),
          );
          Navigator.pop(context);
        }
      });
    }
    _sincronizarMiembros();
  }

  Future<void> _cargarAttendanceEventDoc() async {
    final id = widget.attendanceEventId;
    if (id == null) return;
    try {
      final ev = await _attendanceService.getEventById(id);
      if (mounted) setState(() => _attendanceEventCached = ev);
    } catch (_) {
      debugPrint('Error cargando attendance_event');
    }
  }

  /// Ejecuta sincronización de members a personas en segundo plano
  Future<void> _sincronizarMiembros() async {
    try {
      debugPrint('🔄 Ejecutando sincronización members → personas...');
      final resultado = await _service.sincronizarMiembrosConPersonas();
      debugPrint('✅ Sincronización completada: $resultado');

      if (mounted) {
        final total = resultado['total_procesados'] ?? 0;
        final sincronizados = resultado['sincronizados'] ?? 0;

        if (sincronizados > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Se sincronizaron $sincronizados de $total miembros',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error en sincronización: $e');
    }
  }

  @override
  void dispose() {
    _justificacionController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _identificadorController.dispose();
    super.dispose();
  }

  /// Construye un stream combinado de Members (gestión sindical) y Personas legacy
  /// para mostrar todas las personas disponibles en un solo dropdown.
  /// Evita duplicados basándose en el identificador único.
  Stream<List<Map<String, dynamic>>> _buildCombinedMembersStream() {
    // Usar StreamController para combinar datos de ambas fuentes
    return _membersService.getAllMembers().asyncExpand((members) {
      // Crear un stream que emita el resultado combinado
      return _combinarPersonasYMembers(members).asStream();
    });
  }

  /// Método auxiliar para combinar members y personas legacy
  Future<List<Map<String, dynamic>>> _combinarPersonasYMembers(
    List<Member> members,
  ) async {
    final result = <Map<String, dynamic>>[];
    final identificadoresVistos = <String>{};

    debugPrint(
      '🔄 Combinando ${members.length} members con personas legacy...',
    );

    try {
      // 1. Agregar Members (prioridad alta)
      for (final member in members) {
        final identificador = member.workerCode?.isNotEmpty == true
            ? member.workerCode!
            : (member.documentId ?? '');

        if (identificador.isEmpty) {
          debugPrint(
            '⚠️ Omitiendo member ${member.fullName}: sin identificador',
          );
          continue;
        }

        // Marcar como visto para evitar duplicados
        identificadoresVistos.add(identificador);

        final persona = PersonaAsistencia(
          id: member.id,
          nombres: member.firstName,
          apellidos: member.lastName,
          identificador: identificador,
        );

        result.add({'id': member.id, 'persona': persona, 'source': 'member'});
      }

      debugPrint('   ✅ Agregados ${result.length} members');

      // 2. Agregar Personas legacy que NO estén ya en members
      try {
        final personasSnapshot = await _service.firestore
            .collection('personas')
            .get();

        debugPrint(
          '   📊 Encontradas ${personasSnapshot.docs.length} personas legacy',
        );

        int personasAgregadas = 0;
        for (final doc in personasSnapshot.docs) {
          try {
            final persona = PersonaAsistencia.fromMap(doc.data(), doc.id);

            // Solo agregar si no tiene identificador o si el identificador no está en members
            final identificador = persona.identificador;
            if (identificador != null && identificador.isNotEmpty) {
              if (identificadoresVistos.contains(identificador)) {
                debugPrint('   ⏭️ Saltando persona duplicada: $identificador');
                continue; // Ya existe en members, saltar
              }
              identificadoresVistos.add(identificador);
            }

            result.add({
              'id': persona.id,
              'persona': persona,
              'source': 'persona',
            });
            personasAgregadas++;
          } catch (e) {
            debugPrint('   ❌ Error procesando persona ${doc.id}: $e');
          }
        }

        debugPrint('   ✅ Agregadas $personasAgregadas personas legacy');
      } catch (e) {
        debugPrint('⚠️ Error cargando personas legacy: $e');
        // Continuar con solo members si hay error
      }

      // Ordenar por apellido
      result.sort((a, b) {
        final pa = a['persona'] as PersonaAsistencia;
        final pb = b['persona'] as PersonaAsistencia;
        return pa.apellidos.toLowerCase().compareTo(pb.apellidos.toLowerCase());
      });

      debugPrint(
        '📊 Total personas cargadas: ${result.length} (${result.where((r) => r['source'] == 'member').length} members, ${result.where((r) => r['source'] == 'persona').length} legacy)',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Error en _combinarPersonasYMembers: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Registro Manual',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 150,
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta de información del evento
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event_note,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Información del Evento',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_esModoAttendanceNuevo) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Este registro se asociará al evento de asistencia seleccionado '
                              'y se usará para calcular presentes y faltantes.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.blue.shade800),
                            ),
                          ),
                          _infoRow(
                            label: 'Nombre:',
                            value:
                                _attendanceEventCached?.nombre ?? 'Cargando…',
                          ),
                          _infoRow(
                            label: 'Fecha:',
                            value: _formatDate(
                              _attendanceEventCached?.fecha ??
                                  DateTime.now().millisecondsSinceEpoch,
                            ),
                          ),
                          _infoRow(
                            label: 'Lugar:',
                            value: _attendanceEventCached?.lugar ?? '—',
                          ),
                          _infoRow(
                            label: 'Tipo:',
                            value: _attendanceEventCached?.tipo ?? '—',
                          ),
                        ] else if (widget.evento != null) ...[
                          _infoRow(
                            label: 'Nombre:',
                            value: widget.evento!.nombre,
                          ),
                          _infoRow(
                            label: 'Fecha:',
                            value: _formatDate(widget.evento!.fecha),
                          ),
                          _infoRow(
                            label: 'Tipo:',
                            value: _formatTipoReunion(
                              widget.evento!.tipoReunion.value,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Selector de tipo de registro
                if (!_esModoAttendanceNuevo) ...[
                  Text(
                    'Tipo de Registro',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Persona Existente'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Nueva Persona'),
                        icon: Icon(Icons.person_add),
                      ),
                    ],
                    selected: {_usarNueva},
                    onSelectionChanged: (s) =>
                        setState(() => _usarNueva = s.first),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  Text(
                    'Selecciona un socio del padrón (personas marcadas provenientes del módulo Socios aparecen como verificado).',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Campos según el tipo de registro
                if (_usarNueva) ...[
                  _buildSectionTitle(context, 'Datos de la Persona'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nombresController,
                    decoration: InputDecoration(
                      labelText: 'Nombres *',
                      hintText: 'Ingrese los nombres completos',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apellidosController,
                    decoration: InputDecoration(
                      labelText: 'Apellidos *',
                      hintText: 'Ingrese los apellidos completos',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _identificadorController,
                    decoration: InputDecoration(
                      labelText: 'Número de Trabajador *',
                      hintText:
                          'Ej: 12345 (obligatorio para evitar duplicados)',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ] else
                  // Mostrar lista combinada de Members y Personas legacy
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _buildCombinedMembersStream(),
                    builder: (context, snap) {
                      // Manejar errores
                      if (snap.hasError) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error al cargar personas',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No se pudieron cargar los datos. Intente nuevamente.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () => setState(
                                    () {},
                                  ), // Rebuild para reintentar
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Estado de carga
                      if (!snap.hasData) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Cargando personas...',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final personas = snap.data!;

                      // Estado vacío
                      if (personas.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_off,
                                  size: 48,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay personas registradas',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Agregue personas en la sección "Socios" o use la opción "Nueva Persona"',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Si no hay persona seleccionada, seleccionar la primera
                      if (_personaIdSeleccionada == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && personas.isNotEmpty) {
                            setState(() {
                              _personaIdSeleccionada =
                                  personas.first['id'] as String;
                              _personaObj =
                                  personas.first['persona']
                                      as PersonaAsistencia;
                              _personaSource =
                                  personas.first['source'] as String? ??
                                  'member';
                            });
                          }
                        });
                      }

                      // Asegurar que _personaObj esté sincronizado
                      if (_personaIdSeleccionada != null) {
                        final found = personas
                            .where((p) => p['id'] == _personaIdSeleccionada)
                            .firstOrNull;

                        if (found != null) {
                          _personaObj = found['persona'] as PersonaAsistencia;
                          _personaSource =
                              found['source'] as String? ?? 'persona';
                        } else {
                          // Si no se encuentra, limpiar selección
                          _personaIdSeleccionada = null;
                          _personaObj = null;
                          _personaSource = 'member';
                        }
                      }

                      return _selectorPersonaBuscable(context, personas);
                    },
                  ),
                const SizedBox(height: 24),
                // Sección de estado de asistencia
                _buildSectionTitle(context, 'Estado de Asistencia'),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Row(
                      children: [
                        Icon(
                          _asistio ? Icons.check_circle : Icons.cancel,
                          color: _asistio
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _asistio
                                ? 'La persona ASISTIÓ al evento'
                                : 'La persona NO ASISTIÓ al evento',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _asistio
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      _asistio
                          ? 'Registrado como presente'
                          : 'Registrado como ausente',
                    ),
                    value: _asistio,
                    onChanged: (v) => setState(() => _asistio = v),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    isThreeLine: true,
                  ),
                ),
                const SizedBox(height: 24),
                // Justificación
                _buildSectionTitle(context, 'Justificación'),
                const SizedBox(height: 12),
                TextField(
                  controller: _justificacionController,
                  decoration: InputDecoration(
                    labelText: 'Justificación o Motivo *',
                    hintText:
                        'Describa el motivo del registro (ej: llegó tarde, se retiró temprano, etc.)',
                    prefixIcon: const Icon(Icons.note_alt),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  minLines: 2,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const Spacer(),
                // Botón de guardar
                FilledButton.icon(
                  onPressed: _loading || !_puedeGuardar ? null : _guardar,
                  icon: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_alt),
                  label: Text(
                    _loading
                        ? 'Guardando...'
                        : 'Guardar Registro de Asistencia',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Texto de ayuda
                Text(
                  '* Los campos marcados con asterisco son obligatorios',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _infoRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTipoReunion(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'presencial':
        return 'Presencial';
      case 'virtual':
        return 'Virtual';
      case 'hibrida':
        return 'Híbrida';
      default:
        return tipo;
    }
  }

  bool get _puedeGuardar {
    if (_justificacionController.text.trim().isEmpty) return false;
    if (_usarNueva) {
      // Para nueva persona: nombres, apellidos Y identificador son obligatorios
      return _nombresController.text.trim().isNotEmpty &&
          _apellidosController.text.trim().isNotEmpty &&
          _identificadorController.text.trim().isNotEmpty;
    }
    return _personaObj != null;
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Cerrar',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_puedeGuardar) {
      _mostrarError('Por favor, complete todos los campos obligatorios (*)');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_esModoAttendanceNuevo) {
        final attId = widget.attendanceEventId;
        if (attId == null || attId.isEmpty) {
          _mostrarError('Evento de asistencia inválido');
          setState(() => _loading = false);
          return;
        }
        if (_personaObj == null) {
          _mostrarError('Debe seleccionar una persona');
          setState(() => _loading = false);
          return;
        }
        if (_personaSource != 'member' &&
            (_personaObj!.identificador == null ||
                _personaObj!.identificador!.trim().isEmpty)) {
          _mostrarError(
            'La persona seleccionada no tiene número de trabajador o documento '
            'reconocible. Actualícelo en Socios o elija otro socio.',
          );
          setState(() => _loading = false);
          return;
        }
        final memberId = await _memberIdFirestoreParaAttendance();
        if (memberId == null || memberId.isEmpty) {
          _mostrarError(
            'No se pudo relacionar esta fila con un documento en la colección '
            'members. Revise código de trabajador, número o documento en Socios.',
          );
          setState(() => _loading = false);
          return;
        }
        final existe = await _attendanceService.hasAttendanceRecord(
          attId,
          memberId,
        );
        if (existe) {
          _mostrarError(
            'Ya existe un registro para este socio en este evento de asistencia',
          );
          setState(() => _loading = false);
          return;
        }
        final nota = _justificacionController.text.trim();
        await _attendanceService.registerAttendance(
          eventId: attId,
          personaId: memberId,
          asistio: _asistio,
          metodo: MetodoRegistro.manual,
          observaciones: nota.isEmpty ? null : nota,
        );
        if (!mounted) return;
        _mostrarExito('Asistencia registrada correctamente');
        Navigator.pop(context);
        return;
      }

      if (_usarNueva) {
        // Verificar si ya existe persona con ese identificador
        final identificador = _identificadorController.text.trim();
        final personaExistente = await _service.getPersonaPorIdentificador(
          identificador,
        );

        if (personaExistente != null) {
          _mostrarError(
            '⚠️ Ya existe una persona con número de trabajador: $identificador. Seleccione "Persona Existente"',
          );
          setState(() => _loading = false);
          return;
        }

        // Crear nueva persona
        final p = PersonaAsistencia(
          id: '',
          nombres: _nombresController.text.trim(),
          apellidos: _apellidosController.text.trim(),
          identificador: identificador,
        );

        final id = await _service.createPersona(p);
        final res = await _service.registrarAsistenciaManual(
          id,
          widget.evento!.id,
          _asistio,
          _justificacionController.text.trim(),
        );

        if (res != null && mounted) {
          _mostrarExito(
            '✅ Persona creada y asistencia registrada correctamente',
          );
          Navigator.pop(context);
        } else if (mounted) {
          _mostrarError(
            '⚠️ Ya existe un registro para esta persona en el evento',
          );
        }
      } else {
        // Usar persona existente
        if (_personaObj == null) {
          _mostrarError('⚠️ Debe seleccionar una persona');
          setState(() => _loading = false);
          return;
        }

        // Verificar que la persona tenga identificador
        if (_personaObj!.identificador == null ||
            _personaObj!.identificador!.isEmpty) {
          _mostrarError(
            '⚠️ La persona seleccionada no tiene número de trabajador. Edítela en la sección "Socios"',
          );
          setState(() => _loading = false);
          return;
        }

        final res = await _service.registrarAsistenciaManual(
          _personaObj!.id,
          widget.evento!.id,
          _asistio,
          _justificacionController.text.trim(),
        );

        if (res != null && mounted) {
          _mostrarExito('✅ Asistencia registrada correctamente');
          Navigator.pop(context);
        } else if (mounted) {
          _mostrarError(
            '⚠️ Ya existe un registro para esta persona en el evento',
          );
        }
      }
    } catch (e) {
      debugPrint('Error al registrar asistencia: $e');
      if (mounted) {
        _mostrarError('❌ Error al guardar. Por favor, intente nuevamente');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String?> _memberIdFirestoreParaAttendance() async {
    final p = _personaObj;
    if (p == null) return null;
    if (_personaSource == 'member') {
      final doc = await _membersService.getMemberById(p.id);
      return doc?.id;
    }
    final raw = p.identificador?.trim();
    if (raw != null && raw.isNotEmpty) {
      Member? m = await _membersService.getMemberByWorkerCode(raw);
      m ??= await _membersService.getMemberByNumber(raw);
      m ??= await _membersService.getMemberByDocument(raw);
      if (m != null) return m.id;
    }
    final byId = await _membersService.getMemberById(p.id);
    return byId?.id;
  }

  Future<void> _abrirBuscadorPersona(
    List<Map<String, dynamic>> personas,
  ) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final height = MediaQuery.sizeOf(ctx).height * 0.88;
        return SizedBox(
          height: height,
          child: _PersonaPickSheet(
            entries: personas,
            selectedId: _personaIdSeleccionada,
          ),
        );
      },
    );
    if (!mounted || id == null) return;
    setState(() {
      _personaIdSeleccionada = id;
      Map<String, dynamic>? found;
      for (final row in personas) {
        if (row['id'] == id) {
          found = row;
          break;
        }
      }
      _personaObj = found != null
          ? found['persona'] as PersonaAsistencia
          : null;
      _personaSource = found != null
          ? (found['source'] as String? ?? 'persona')
          : 'member';
    });
  }

  Widget _selectorPersonaBuscable(
    BuildContext context,
    List<Map<String, dynamic>> personas,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _abrirBuscadorPersona(personas),
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Seleccionar persona *',
            hintText: 'Toca para buscar',
            prefixIcon: const Icon(Icons.person_search),
            suffixIcon: const Icon(Icons.keyboard_arrow_down),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          child: Text(
            _personaObj?.nombreCompleto ?? 'Buscar persona…',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: _personaObj != null
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: _personaObj == null ? Theme.of(context).hintColor : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _PersonaPickSheet extends StatefulWidget {
  const _PersonaPickSheet({required this.entries, required this.selectedId});

  final List<Map<String, dynamic>> entries;
  final String? selectedId;

  @override
  State<_PersonaPickSheet> createState() => _PersonaPickSheetState();
}

class _PersonaPickSheetState extends State<_PersonaPickSheet> {
  final TextEditingController _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtradas {
    final q = _filter.text.trim().toLowerCase();
    if (q.isEmpty) return widget.entries;
    return widget.entries.where((item) {
      final p = item['persona'] as PersonaAsistencia;
      final idStr = '${item['id']}'.toLowerCase();
      return p.nombreCompleto.toLowerCase().contains(q) ||
          (p.identificador?.toLowerCase().contains(q) ?? false) ||
          idStr.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: const Text('Buscar persona'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _filter,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nombre, identificador, id…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filtradas.length,
            itemBuilder: (ctx, i) {
              final item = _filtradas[i];
              final p = item['persona'] as PersonaAsistencia;
              final src = item['source'] as String;
              final id = item['id'] as String;
              final seleccionado = widget.selectedId == id;
              return ListTile(
                leading: Icon(
                  seleccionado
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(p.nombreCompleto),
                subtitle: Text(
                  p.identificador?.isNotEmpty == true ? p.identificador! : id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: src == 'member'
                    ? Icon(Icons.verified_user, color: Colors.green.shade700)
                    : null,
                onTap: () => Navigator.pop(context, id),
              );
            },
          ),
        ),
      ],
    );
  }
}
