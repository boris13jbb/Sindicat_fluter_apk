import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/models/member.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/attendance_service.dart';
import '../../services/members_service.dart';
import 'route_args.dart';

/// Detalle y operaciones para un doc en colección **`attendance_events`**.
class AttendanceEventDetailScreen extends StatelessWidget {
  const AttendanceEventDetailScreen({super.key, required this.eventId});

  final String eventId;

  static String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final attendanceSvc = AttendanceService();

    Future<void> openModalidadesEditor() async {
      final messenger = ScaffoldMessenger.of(context);
      AttendanceEvent? ev;
      try {
        ev = await attendanceSvc.getEventById(eventId);
      } catch (e) {
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('No se pudo cargar el evento: $e')),
          );
        }
        return;
      }
      if (!context.mounted) return;
      if (ev == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Evento no encontrado')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => _EditModalidadesNoConvocadasDialog(
          attendanceSvc: attendanceSvc,
          event: ev!,
        ),
      );
    }

    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Evento de asistencia',
        onNavigateBack: () => Navigator.pop(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            tooltip: 'Editar modalidades no convocadas',
            onPressed: openModalidadesEditor,
          ),
          IconButton(
            icon: const Icon(Icons.view_list_rounded),
            tooltip: 'Ir al listado de asistencia',
            onPressed: () {
              // Siempre muestra `/asistencia` aunque el detalle se abriera sin esa
              // ruta en la pila (p. ej. deep link futuro): se conserva la raíz (`isFirst`)
              // y se apila el hub de asistencia encima.
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/asistencia',
                (route) => route.isFirst,
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('attendance_events')
                .doc(eventId)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: ${snap.error}'),
                );
              }
              if (!snap.hasData || !snap.data!.exists) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Cargando evento…'),
                    ],
                  ),
                );
              }
              final map = snap.data!.data() ?? {};
              final nombre = map['nombre'] as String? ?? '(sin nombre)';
              final fecha = (map['fecha'] as num?)?.toInt() ?? 0;
              final fechaFin = (map['fechaFin'] as num?)?.toInt();
              final lugar = map['lugar'] as String? ?? '';
              final tipo = map['tipo'] as String? ?? '';
              final desc = map['descripcion'] as String?;
              final modalidadesRaw = List<String>.from(
                map['modalidadesNoConvocadas'] ?? [],
              );
              final modalidadesEtiquetas = modalidadesRaw
                  .map(Modalidad.tryParse)
                  .whereType<Modalidad>()
                  .map(JustificacionHelper.etiquetaModalidad)
                  .toList();
              return Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Inicio: ${_fmt(fecha)}'),
                      if (fechaFin != null)
                        Text('Fin: ${_fmt(fechaFin)}')
                      else
                        Text(
                          'Fin: fin del día del inicio (documento sin fechaFin)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      if (lugar.isNotEmpty) Text('Lugar: $lugar'),
                      if (tipo.isNotEmpty) Chip(label: Text(tipo)),
                      if (desc != null && desc.isNotEmpty) Text(desc),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              'Modalidades no convocadas',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: openModalidadesEditor,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Editar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (modalidadesEtiquetas.isEmpty)
                        Text(
                          'Ninguna modalidad excluida; todas pueden entrar en la convocatoria según la lista de socios.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: modalidadesEtiquetas
                              .map(
                                (label) => Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(label),
                                ),
                              )
                              .toList(),
                        ),
                      const Divider(height: 24),
                      Text(
                        'ID interno Firestore:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      SelectableText(
                        eventId,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registros de asistencia',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estos registros se usan para calcular presentes y faltantes.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: _AttendanceEventRecordsList(
              eventId: eventId,
              attendanceSvc: attendanceSvc,
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'att_ev_report',
            tooltip: 'Ver reporte calculado',
            onPressed: () => Navigator.pushNamed(
              context,
              '/attendance/report',
              arguments: eventId,
            ),
            child: const Icon(Icons.bar_chart),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'att_ev_manual',
            tooltip: 'Registro manual (modelo nuevo)',
            onPressed: () => Navigator.pushNamed(
              context,
              '/asistencia/registro_manual',
              arguments: AsistenciaEventRouteArgs.attendance(eventId),
            ),
            child: const Icon(Icons.person_add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'att_ev_scan',
            tooltip: 'Escanear (modelo nuevo)',
            onPressed: () => Navigator.pushNamed(
              context,
              '/asistencia/scanner',
              arguments: AsistenciaEventRouteArgs.attendance(
                eventId,
                openScannerDirectly: true,
              ),
            ),
            child: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
    );
  }
}

/// Lista de asistencias del evento con datos del padrón `members` (nombre, N°, cédula, modalidad).
class _AttendanceEventRecordsList extends StatefulWidget {
  const _AttendanceEventRecordsList({
    required this.eventId,
    required this.attendanceSvc,
  });

  final String eventId;
  final AttendanceService attendanceSvc;

  @override
  State<_AttendanceEventRecordsList> createState() =>
      _AttendanceEventRecordsListState();
}

class _AttendanceEventRecordsListState extends State<_AttendanceEventRecordsList> {
  final MembersService _membersService = MembersService();
  final Map<String, Member?> _memberByPersonaId = {};
  final Set<String> _loadingPersonaIds = {};

  static String _fmtRegistro(int? ms) {
    if (ms == null || ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Future<Member?> _resolveMember(String personaId) async {
    if (personaId.isEmpty) return null;
    var m = await _membersService.getMemberById(personaId);
    m ??= await _membersService.getMemberByWorkerCode(personaId);
    m ??= await _membersService.getMemberByNumber(personaId);
    m ??= await _membersService.getMemberByDocument(personaId);
    return m;
  }

  void _scheduleLoadsFor(List<AsistenciaRegistro> list) {
    final ids = list.map((r) => r.personaId).where((s) => s.isNotEmpty).toSet();
    for (final id in ids) {
      if (_memberByPersonaId.containsKey(id) || _loadingPersonaIds.contains(id)) {
        continue;
      }
      _loadingPersonaIds.add(id);
      _resolveMember(id).then((m) {
        if (!mounted) return;
        setState(() {
          _loadingPersonaIds.remove(id);
          _memberByPersonaId[id] = m;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return StreamBuilder<List<AsistenciaRegistro>>(
      stream: widget.attendanceSvc.getEventAttendances(widget.eventId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final list = snap.data;
        if (list == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Sin registros.\n\n'
                'Usa el botón QR (abajo) o Registro manual para añadir asistencias.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          );
        }

        _scheduleLoadsFor(list);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final r = list[i];
            final pid = r.personaId;
            final loading = pid.isNotEmpty && _loadingPersonaIds.contains(pid);
            final member = pid.isEmpty ? null : _memberByPersonaId[pid];
            final resuelto = pid.isEmpty || _memberByPersonaId.containsKey(pid);
            final noEnPadron =
                pid.isNotEmpty && resuelto && member == null && !loading;

            final nombreMostrado = pid.isEmpty
                ? 'Sin identificador de socio'
                : (member?.fullName.trim().isNotEmpty == true
                    ? member!.fullName
                    : (loading
                        ? 'Cargando datos del socio…'
                        : 'Socio no encontrado'));

            final estadoTxt =
                r.asistio ? 'Asistió' : 'No asistió';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          r.asistio ? Icons.check_circle : Icons.cancel,
                          color:
                              r.asistio ? Colors.green.shade700 : cs.error,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombreMostrado,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$estadoTxt • ${_fmtRegistro(r.fechaRegistro)}'
                                '${r.metodoRegistro == MetodoRegistro.manual ? '' : ' · ${r.metodoRegistro.value}'}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              if (r.justificacion?.trim().isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Text(
                                  r.justificacion!.trim(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!loading && member != null) ...[
                      const SizedBox(height: 12),
                      _metaRow(
                        context,
                        Icons.badge_outlined,
                        'N° Socio',
                        member.memberNumber,
                      ),
                      if (member.documentId?.trim().isNotEmpty == true)
                        _metaRow(
                          context,
                          Icons.credit_card_outlined,
                          'Cédula',
                          member.documentId!,
                        ),
                      _metaRow(
                        context,
                        Icons.schedule_outlined,
                        'Modalidad',
                        member.modalidad != null
                            ? JustificacionHelper.etiquetaModalidad(
                                member.modalidad!,
                              )
                            : 'Sin asignar',
                      ),
                    ] else if (pid.isEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'El registro no tiene personaId. Revise el guardado en Firestore.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.error,
                        ),
                      ),
                    ] else if (noEnPadron) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Referencia en registro: $pid\n'
                        'No hay coincidencia en el padrón por id de documento, '
                        'código trabajador o número de socio.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.error,
                        ),
                      ),
                    ] else if (loading) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 4,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _metaRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditModalidadesNoConvocadasDialog extends StatefulWidget {
  const _EditModalidadesNoConvocadasDialog({
    required this.attendanceSvc,
    required this.event,
  });

  final AttendanceService attendanceSvc;
  final AttendanceEvent event;

  @override
  State<_EditModalidadesNoConvocadasDialog> createState() =>
      _EditModalidadesNoConvocadasDialogState();
}

class _EditModalidadesNoConvocadasDialogState
    extends State<_EditModalidadesNoConvocadasDialog> {
  late Set<Modalidad> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.event.modalidadesNoConvocadas
        .map(Modalidad.tryParse)
        .whereType<Modalidad>()
        .toSet();
  }

  Future<void> _guardar() async {
    setState(() => _saving = true);
    try {
      await widget.attendanceSvc.updateEvent(
        widget.event.copyWith(
          modalidadesNoConvocadas:
              _selected.map((m) => m.value).toList(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modalidades no convocadas actualizadas'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Modalidades no convocadas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Marca las modalidades que no aplican a esta convocatoria.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  Modalidad.valoresParaJustificacionAsistencia.map((modalidad) {
                final on = _selected.contains(modalidad);
                return FilterChip(
                  selected: on,
                  label: Text(
                    JustificacionHelper.etiquetaModalidad(modalidad),
                  ),
                  onSelected: _saving
                      ? null
                      : (checked) {
                          setState(() {
                            if (checked) {
                              _selected.add(modalidad);
                            } else {
                              _selected.remove(modalidad);
                            }
                          });
                        },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _guardar,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
