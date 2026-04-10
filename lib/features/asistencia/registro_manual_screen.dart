import 'package:flutter/material.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/models/asistencia/persona.dart';
import '../../core/models/member.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';
import '../../services/members_service.dart';

class RegistroManualScreen extends StatefulWidget {
  const RegistroManualScreen({super.key, required this.evento});

  final EventoAsistencia evento;

  @override
  State<RegistroManualScreen> createState() => _RegistroManualScreenState();
}

class _RegistroManualScreenState extends State<RegistroManualScreen> {
  final _service = AsistenciaService();
  final _membersService = MembersService();
  String? _personaIdSeleccionada; // Usar ID en lugar de objeto para Dropdown
  PersonaAsistencia? _personaObj;
  bool _asistio = true;
  final _justificacionController = TextEditingController();
  bool _usarNueva = false;
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _identificadorController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Sincronizar members → personas al cargar la pantalla
    _sincronizarMiembros();
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
    
    debugPrint('🔄 Combinando ${members.length} members con personas legacy...');
    
    try {
      // 1. Agregar Members (prioridad alta)
      for (final member in members) {
        final identificador = member.workerCode?.isNotEmpty == true 
            ? member.workerCode! 
            : (member.documentId ?? '');
        
        if (identificador.isEmpty) {
          debugPrint('⚠️ Omitiendo member ${member.fullName}: sin identificador');
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
        
        result.add({
          'id': member.id,
          'persona': persona,
          'source': 'member',
        });
      }
      
      debugPrint('   ✅ Agregados ${result.length} members');
      
      // 2. Agregar Personas legacy que NO estén ya en members
      try {
        final personasSnapshot = await _service.firestore
            .collection('personas')
            .get();
        
        debugPrint('   📊 Encontradas ${personasSnapshot.docs.length} personas legacy');
        
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
      
      debugPrint('📊 Total personas cargadas: ${result.length} (${result.where((r) => r['source'] == 'member').length} members, ${result.where((r) => r['source'] == 'persona').length} legacy)');
      
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
                        _infoRow(label: 'Nombre:', value: widget.evento.nombre),
                        _infoRow(
                          label: 'Fecha:',
                          value: _formatDate(widget.evento.fecha),
                        ),
                        _infoRow(
                          label: 'Tipo:',
                          value: _formatTipoReunion(
                            widget.evento.tipoReunion.value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Selector de tipo de registro
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
                      hintText: 'Ej: 12345 (obligatorio para evitar duplicados)',
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
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
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
                                  onPressed: () => setState(() {}), // Rebuild para reintentar
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
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay personas registradas',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
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
                              _personaIdSeleccionada = personas.first['id'];
                              _personaObj = personas.first['persona'] as PersonaAsistencia;
                            });
                          }
                        });
                      }
                      
                      // Asegurar que _personaObj esté sincronizado
                      if (_personaIdSeleccionada != null) {
                        final found = personas.where(
                          (p) => p['id'] == _personaIdSeleccionada,
                        ).firstOrNull;
                        
                        if (found != null) {
                          _personaObj = found['persona'] as PersonaAsistencia;
                        } else {
                          // Si no se encuentra, limpiar selección
                          _personaIdSeleccionada = null;
                          _personaObj = null;
                        }
                      }
                      
                      return DropdownButtonFormField<String>(
                        initialValue: _personaIdSeleccionada,
                        decoration: InputDecoration(
                          labelText: 'Seleccionar Persona *',
                          hintText: 'Busque y seleccione una persona',
                          prefixIcon: const Icon(Icons.person_search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                        ),
                        items: personas
                            .map(
                              (item) {
                                final p = item['persona'] as PersonaAsistencia;
                                final source = item['source'] as String;
                                return DropdownMenuItem(
                                  value: p.id,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.nombreCompleto,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (source == 'member')
                                        Icon(
                                          Icons.verified_user,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                    ],
                                  ),
                                );
                              },
                            )
                            .toList(),
                        onChanged: (id) => setState(() {
                          _personaIdSeleccionada = id;
                          final found = personas.where(
                            (p) => p['id'] == id,
                          ).firstOrNull;
                          
                          if (found != null) {
                            _personaObj = found['persona'] as PersonaAsistencia;
                          }
                        }),
                        isExpanded: true,
                      );
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
      if (_usarNueva) {
        // Verificar si ya existe persona con ese identificador
        final identificador = _identificadorController.text.trim();
        final personaExistente = await _service.getPersonaPorIdentificador(identificador);
        
        if (personaExistente != null) {
          _mostrarError('⚠️ Ya existe una persona con número de trabajador: $identificador. Seleccione "Persona Existente"');
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
          widget.evento.id,
          _asistio,
          _justificacionController.text.trim(),
        );

        if (res != null && mounted) {
          _mostrarExito('✅ Persona creada y asistencia registrada correctamente');
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
        if (_personaObj!.identificador == null || _personaObj!.identificador!.isEmpty) {
          _mostrarError('⚠️ La persona seleccionada no tiene número de trabajador. Edítela en la sección "Socios"');
          setState(() => _loading = false);
          return;
        }
        
        final res = await _service.registrarAsistenciaManual(
          _personaObj!.id,
          widget.evento.id,
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
}
