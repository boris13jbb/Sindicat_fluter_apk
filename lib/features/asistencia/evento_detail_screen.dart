import 'package:flutter/material.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/models/member.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';
import '../../services/members_service.dart';

class EventoDetailScreen extends StatefulWidget {
  const EventoDetailScreen({super.key, required this.evento});

  final EventoAsistencia evento;

  @override
  State<EventoDetailScreen> createState() => _EventoDetailScreenState();
}

class _EventoDetailScreenState extends State<EventoDetailScreen> {
  final MembersService _membersService = MembersService();
  late EventoAsistencia _currentEvento;

  @override
  void initState() {
    super.initState();
    _currentEvento = widget.evento;
  }

  /// Método para mostrar el diálogo de selección de modalidad
  Future<void> _mostrarDialogoModalidad() async {
    final seleccionada = await showDialog<Modalidad>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar Modalidad de Turno'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: Modalidad.values.length,
            itemBuilder: (context, index) {
              final modalidad = Modalidad.values[index];
              final descripcion = JustificacionHelper.obtenerDescripcionModalidad(modalidad);
              return ListTile(
                title: Text(descripcion),
                subtitle: Text('Código: ${modalidad.value}'),
                selected: _currentEvento.modalidad == modalidad,
                onTap: () => Navigator.pop(ctx, modalidad),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (seleccionada != null && mounted) {
      setState(() => _currentEvento = _currentEvento.copyWith(modalidad: seleccionada));
      
      // Actualizar en Firestore y propagar justificaciones
      try {
        await AsistenciaService().updateEventoModalidad(
          _currentEvento.id,
          seleccionada,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Modalidad actualizada a: ${seleccionada.value}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Busca un miembro por su identificador (workerCode, memberNumber, o documentId)
  Future<Member?> _buscarMiembroPorIdentificador(String? identificador) async {
    if (identificador == null || identificador.isEmpty) return null;
    
    try {
      debugPrint('🔍 Buscando miembro con identificador: $identificador');
      
      // PRIORIDAD 1: Buscar por workerCode
      debugPrint('   📍 Intentando búsqueda por workerCode...');
      Member? member = await _membersService.getMemberByWorkerCode(identificador);
      if (member != null) {
        debugPrint('   ✅ Miembro encontrado por workerCode: ${member.fullName}');
        return member;
      }
      
      // PRIORIDAD 2: Buscar por memberNumber (N° Socio)
      debugPrint('   📍 Intentando búsqueda por memberNumber...');
      member = await _membersService.getMemberByNumber(identificador);
      if (member != null) {
        debugPrint('   ✅ Miembro encontrado por memberNumber: ${member.fullName}');
        return member;
      }
      
      // PRIORIDAD 3: Buscar por documentId (Cédula)
      debugPrint('   📍 Intentando búsqueda por documentId...');
      member = await _membersService.getMemberByDocument(identificador);
      if (member != null) {
        debugPrint('   ✅ Miembro encontrado por documentId: ${member.fullName}');
        return member;
      }
      
      // PRIORIDAD 4: Buscar por ID de Firestore (fallback)
      debugPrint('   📍 Intentando búsqueda por ID de Firestore...');
      member = await _membersService.getMemberById(identificador);
      if (member != null) {
        debugPrint('   ✅ Miembro encontrado por ID de Firestore: ${member.fullName}');
        return member;
      }
      
      debugPrint('   ❌ No se encontró miembro para identificador: $identificador');
      return null;
    } catch (e) {
      debugPrint('   ⚠️ Error buscando miembro: $e');
      return null;
    }
  }

  static String _formatFecha(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final service = AsistenciaService();
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Detalle del Evento',
        onNavigateBack: () => Navigator.pop(context),
        actions: [
          // 🎯 Botón para editar modalidad
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar modalidad de turno',
            onPressed: _mostrarDialogoModalidad,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar evento'),
                  content: Text('¿Eliminar "${_currentEvento.nombre}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        'Eliminar',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await service.deleteEvento(_currentEvento.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Evento eliminado')),
                  );
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentEvento.nombre,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatFecha(_currentEvento.fecha),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_currentEvento.descripcion != null &&
                      _currentEvento.descripcion!.isNotEmpty)
                    Text(
                      _currentEvento.descripcion!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  // 🆕 Indicador de Modalidad de Turno (muy visible)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _currentEvento.modalidad != null
                          ? Colors.blue.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _currentEvento.modalidad != null
                            ? Colors.blue.shade300
                            : Colors.orange.shade300,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.work_outline,
                              size: 20,
                              color: _currentEvento.modalidad != null
                                  ? Colors.blue.shade700
                                  : Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Modalidad de Turno',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _currentEvento.modalidad != null
                                    ? Colors.blue.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.edit,
                              size: 18,
                              color: _currentEvento.modalidad != null
                                  ? Colors.blue.shade600
                                  : Colors.orange.shade600,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentEvento.modalidad != null
                              ? JustificacionHelper.obtenerDescripcionModalidad(_currentEvento.modalidad!)
                              : 'No asignada - Toca el botón editar para asignar',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: _currentEvento.modalidad != null
                                ? Colors.blue.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                        if (_currentEvento.modalidad != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  JustificacionHelper.obtenerJustificacion(_currentEvento.modalidad!),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.blue.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(label: Text(_currentEvento.tipoReunion.value)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Registros de Asistencia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<AsistenciaConDatos>>(
              stream: service.getAsistenciasPorEventoStream(_currentEvento.id),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'Sin registros aún. Usa Escanear o Registro manual.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final a = list[i];
                    
                    return FutureBuilder<Member?>(
                      future: _buscarMiembroPorIdentificador(a.persona.identificador),
                      builder: (context, snapshot) {
                        final member = snapshot.data;
                        
                        // 🔍 Lógica de display con datos del miembro si están disponibles
                        String displayName;
                        if (member != null) {
                          // Usar datos completos del miembro
                          displayName = member.fullName;
                        } else if (a.persona.nombres.isNotEmpty && a.persona.apellidos.isNotEmpty &&
                            a.persona.nombres != 'Sin nombre' && a.persona.apellidos != 'Sin apellido') {
                          // Mostrar nombre completo de persona si es válido
                          displayName = a.persona.nombreCompleto;
                        } else if (a.persona.identificador != null && a.persona.identificador!.isNotEmpty) {
                          // Fallback: mostrar identificador como texto plano
                          displayName = 'N° Trabajador: ${a.persona.identificador}';
                        } else {
                          // Último recurso
                          displayName = 'Sin nombre Sin apellido';
                        }
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              displayName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${a.asistencia.asistio ? "Asistió" : "No asistió"} • ${_formatFecha(a.asistencia.fechaRegistro ?? 0)}',
                                ),
                                // Mostrar información del socio si está disponible
                                if (member != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.badge,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'N° Socio: ${member.memberNumber}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (member.documentId != null && member.documentId!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.credit_card,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Cédula: ${member.documentId}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                                // Mostrar N° Trabajador si no hay miembro pero sí identificador
                                if (member == null && a.persona.identificador != null && a.persona.identificador!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.badge,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'N° Trabajador: ${a.persona.identificador}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Eliminar registro'),
                                    content: const Text(
                                      '¿Quitar este registro de asistencia?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await service.deleteAsistencia(a.asistencia.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Registro eliminado'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 🆕 Botón para ver reporte con faltas calculadas
          FloatingActionButton.small(
            heroTag: 'report',
            onPressed: () => Navigator.pushNamed(
              context,
              '/attendance/report',
              arguments: _currentEvento.id,
            ),
            tooltip: 'Ver reporte de asistencia',
            child: const Icon(Icons.bar_chart),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'manual',
            onPressed: () => Navigator.pushNamed(
              context,
              '/asistencia/registro_manual',
              arguments: _currentEvento,
            ),
            child: const Icon(Icons.person_add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'scan',
            onPressed: () => Navigator.pushNamed(
              context,
              '/asistencia/scanner',
              arguments: _currentEvento,
            ),
            child: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
    );
  }
}
