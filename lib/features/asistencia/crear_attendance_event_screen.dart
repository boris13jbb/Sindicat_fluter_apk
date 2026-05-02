import 'package:flutter/material.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/models/member.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/attendance_service.dart';
import '../../services/members_service.dart';

/// Alta de eventos operativos en la colección `attendance_events`.
class CrearAttendanceEventScreen extends StatefulWidget {
  const CrearAttendanceEventScreen({super.key});

  @override
  State<CrearAttendanceEventScreen> createState() =>
      _CrearAttendanceEventScreenState();
}

enum _TipoCrearEvento { ordinaria, extraordinaria, escribir }

class _CrearAttendanceEventScreenState
    extends State<CrearAttendanceEventScreen> {
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _lugarController = TextEditingController();
  final _tipoCustomController = TextEditingController();
  final AttendanceService _service = AttendanceService();

  DateTime _fecha = DateTime.now();
  late DateTime _fechaFin;
  _TipoCrearEvento _tipoCrear = _TipoCrearEvento.ordinaria;
  bool _loading = false;

  /// `true`: `miembrosConvocados` vacío → el cálculo usa todos los activos (`AttendanceService`).
  bool _convocatoriaTodosActivos = true;
  final Set<String> _miembrosConvocadosIds = <String>{};

  /// Modalidades excluidas de la convocatoria (`AttendanceEvent.modalidadesNoConvocadas`).
  final Set<Modalidad> _modalidadesNoConvocadas = {};

  @override
  void initState() {
    super.initState();
    final d = _fecha;
    _fechaFin = DateTime(d.year, d.month, d.day, 23, 59);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _lugarController.dispose();
    _tipoCustomController.dispose();
    super.dispose();
  }

  /// Valor persistido en `AttendanceEvent.tipo` (colección `attendance_events`).
  String _tipoParaFirestore() {
    switch (_tipoCrear) {
      case _TipoCrearEvento.ordinaria:
        return 'ordinaria';
      case _TipoCrearEvento.extraordinaria:
        return 'extraordinaria';
      case _TipoCrearEvento.escribir:
        var t = _tipoCustomController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (t.isEmpty) return 'personalizado';
        if (t.length > 80) t = t.substring(0, 80);
        return t.toLowerCase();
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
    );
    if (time == null || !mounted) return;
    setState(() {
      _fecha = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!_fechaFin.isAfter(_fecha)) {
        _fechaFin = DateTime(
          _fecha.year,
          _fecha.month,
          _fecha.day,
          23,
          59,
        );
      }
    });
  }

  Future<void> _pickFechaFin() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaFin.isBefore(_fecha) ? _fecha : _fechaFin,
      firstDate: DateTime(_fecha.year, _fecha.month, _fecha.day),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaFin),
    );
    if (time == null || !mounted) return;
    final fin = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => _fechaFin = fin);
  }

  Future<void> _abrirSeleccionConvocados() async {
    final nueva = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final height = MediaQuery.sizeOf(ctx).height * 0.88;
        return SizedBox(
          height: height,
          child: _SeleccionConvocadosSheet(
            initial: {..._miembrosConvocadosIds},
          ),
        );
      },
    );
    if (nueva != null && mounted) {
      setState(
        () => _miembrosConvocadosIds
          ..clear()
          ..addAll(nueva),
      );
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final lugar = _lugarController.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del evento es obligatorio')),
      );
      return;
    }
    if (lugar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El lugar o sede es obligatorio')),
      );
      return;
    }
    if (!_convocatoriaTodosActivos && _miembrosConvocadosIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Elige convocados específicos o vuelve a «Todos los socios activos».',
          ),
        ),
      );
      return;
    }
    if (!_fechaFin.isAfter(_fecha)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La fecha y hora de fin deben ser posteriores al inicio del evento.',
          ),
        ),
      );
      return;
    }
    if (_tipoCrear == _TipoCrearEvento.escribir &&
        _tipoCustomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe el tipo personalizado o elige Ordinaria / Extraordinaria.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final eventId = await _service.createEvent(
        AttendanceEvent(
          id: '',
          nombre: nombre,
          descripcion: _descripcionController.text.trim(),
          fecha: _fecha.millisecondsSinceEpoch,
          fechaFin: _fechaFin.millisecondsSinceEpoch,
          lugar: lugar,
          tipo: _tipoParaFirestore(),
          activo: true,
          miembrosConvocados: _convocatoriaTodosActivos
              ? []
              : _miembrosConvocadosIds.toList(),
          modalidadesNoConvocadas: _modalidadesNoConvocadas
              .map((m) => m.value)
              .toList(),
          creadoPor: '',
          createdAt: 0,
        ),
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      // Cierra esta ruta con el nuevo id (`Future` del `pushNamed` que abrió la pantalla).
      navigator.pop(eventId);
      // Abre detalle después del frame actual para mantener orden de rutas válido.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator.pushNamed(
          '/asistencia/attendance_event_detail',
          arguments: eventId,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Crear evento de asistencia',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evento de asistencia',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Define la convocatoria del evento y permite calcular presentes, faltas y socios no convocados. '
                      'Con «Todos los socios activos», se incluye el padrón activo completo.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Convocatoria'),
              subtitle: Text(
                _convocatoriaTodosActivos
                    ? 'Todos los socios activos'
                    : 'Lista personalizada (${_miembrosConvocadosIds.length})',
              ),
              value: _convocatoriaTodosActivos,
              onChanged: (v) => setState(() {
                _convocatoriaTodosActivos = v;
                if (v) _miembrosConvocadosIds.clear();
              }),
            ),
            if (!_convocatoriaTodosActivos)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: _abrirSeleccionConvocados,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(
                    _miembrosConvocadosIds.isEmpty
                        ? 'Elegir convocados'
                        : 'Editar convocados (${_miembrosConvocadosIds.length})',
                  ),
                ),
              ),
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del evento *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lugarController,
              decoration: const InputDecoration(
                labelText: 'Lugar / sede *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Tipo', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Ordinaria'),
                  selected: _tipoCrear == _TipoCrearEvento.ordinaria,
                  onSelected: (_) => setState(() => _tipoCrear = _TipoCrearEvento.ordinaria),
                ),
                FilterChip(
                  label: const Text('Extraordinaria'),
                  selected: _tipoCrear == _TipoCrearEvento.extraordinaria,
                  onSelected: (_) =>
                      setState(() => _tipoCrear = _TipoCrearEvento.extraordinaria),
                ),
                FilterChip(
                  label: const Text('Escribir…'),
                  selected: _tipoCrear == _TipoCrearEvento.escribir,
                  onSelected: (_) => setState(() => _tipoCrear = _TipoCrearEvento.escribir),
                ),
              ],
            ),
            if (_tipoCrear == _TipoCrearEvento.escribir) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _tipoCustomController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tipo personalizado *',
                  hintText: 'Ej.: reunión de delegados',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Modalidades no convocadas',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Marca las modalidades que no aplican a esta convocatoria. '
              'Los socios en esas modalidades no se cuentan como convocados ni como faltas injustificadas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _CrearAttendanceInfoBox(
              icon: Icons.info_outline,
              color: Colors.blue,
              text:
                  'Solo las modalidades marcadas quedan fuera del cómputo de convocatoria.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  Modalidad.valoresParaJustificacionAsistencia.map((modalidad) {
                    final selected =
                        _modalidadesNoConvocadas.contains(modalidad);
                    return FilterChip(
                      selected: selected,
                      avatar: selected ? const Icon(Icons.check, size: 18) : null,
                      label: Text(
                        JustificacionHelper.etiquetaModalidad(modalidad),
                      ),
                      onSelected: (checked) {
                        setState(() {
                          if (checked) {
                            _modalidadesNoConvocadas.add(modalidad);
                          } else {
                            _modalidadesNoConvocadas.remove(modalidad);
                          }
                        });
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 8),
            _CrearAttendanceInfoBox(
              icon: Icons.rule,
              color: _modalidadesNoConvocadas.isEmpty
                  ? Colors.orange
                  : Colors.green,
              text: _modalidadesNoConvocadas.isEmpty
                  ? 'Sin exclusiones: todas las modalidades entran en la convocatoria según la lista de socios.'
                  : 'No convocadas: ${_modalidadesNoConvocadas.map(JustificacionHelper.etiquetaModalidad).join(', ')}.',
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha y hora de inicio'),
              subtitle: Text(
                '${_fecha.day}/${_fecha.month}/${_fecha.year} '
                '${_fecha.hour.toString().padLeft(2, '0')}:'
                '${_fecha.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDateTime,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha y hora de fin'),
              subtitle: Text(
                '${_fechaFin.day}/${_fechaFin.month}/${_fechaFin.year} '
                '${_fechaFin.hour.toString().padLeft(2, '0')}:'
                '${_fechaFin.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.event_available_outlined),
              onTap: _pickFechaFin,
            ),
            const SizedBox(height: 8),
            Text(
              'El evento se considera vigente para vínculos (p. ej. elecciones) '
              'mientras esté activo y no haya pasado la fecha de fin.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.save),
                label: const Text('Guardar evento'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SeleccionConvocadosSheet extends StatefulWidget {
  const _SeleccionConvocadosSheet({required this.initial});

  final Set<String> initial;

  @override
  State<_SeleccionConvocadosSheet> createState() =>
      _SeleccionConvocadosSheetState();
}

class _SeleccionConvocadosSheetState extends State<_SeleccionConvocadosSheet> {
  final MembersService _membersService = MembersService();
  final TextEditingController _filtro = TextEditingController();

  late Set<String> _seleccion;

  @override
  void initState() {
    super.initState();
    _seleccion = {...widget.initial};
    _filtro.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filtro.dispose();
    super.dispose();
  }

  void _marcarTodos(Iterable<String> ids, bool seleccionar) {
    setState(() {
      for (final id in ids) {
        if (seleccionar) {
          _seleccion.add(id);
        } else {
          _seleccion.remove(id);
        }
      }
    });
  }

  List<Member> _filtrar(List<Member> members) {
    final q = _filtro.text.trim().toLowerCase();
    if (q.isEmpty) return members;
    return members.where((m) {
      return m.fullName.toLowerCase().contains(q) ||
          m.memberNumber.toLowerCase().contains(q) ||
          (m.workerCode?.toLowerCase().contains(q) ?? false) ||
          (m.documentId?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: const Text('Convocados'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _seleccion),
              child: const Text('Listo'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _filtro,
            decoration: const InputDecoration(
              hintText: 'Buscar nombre, número, trabajador, documento…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        StreamBuilder<List<Member>>(
          stream: _membersService.getAllMembers(status: MemberStatus.active),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Expanded(
                child: Center(child: Text('Error: ${snapshot.error}')),
              );
            }
            if (!snapshot.hasData) {
              return const Expanded(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final visibles = _filtrar(snapshot.data!);
            final todosIds = visibles.map((m) => m.id).toList();
            return Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: todosIds.isEmpty
                              ? null
                              : () => _marcarTodos(todosIds, true),
                          child: const Text('Seleccionar visibles'),
                        ),
                        TextButton(
                          onPressed: todosIds.isEmpty
                              ? null
                              : () => _marcarTodos(todosIds, false),
                          child: const Text('Limpiar visibles'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: visibles.length,
                      itemBuilder: (context, i) {
                        final m = visibles[i];
                        final marca = _seleccion.contains(m.id);
                        return CheckboxListTile(
                          value: marca,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _seleccion.add(m.id);
                            } else {
                              _seleccion.remove(m.id);
                            }
                          }),
                          secondary: CircleAvatar(
                            child: Text(
                              m.firstName.isNotEmpty
                                  ? m.firstName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(m.fullName),
                          subtitle: Text(
                            '${m.memberNumber}'
                            '${m.workerCode?.isNotEmpty == true ? ' · ${m.workerCode}' : ''}',
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_seleccion.length} seleccionados'),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, _seleccion),
                            child: const Text('Confirmar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CrearAttendanceInfoBox extends StatelessWidget {
  const _CrearAttendanceInfoBox({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color.withValues(alpha: 0.9),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
