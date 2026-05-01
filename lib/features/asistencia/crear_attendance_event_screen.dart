import 'package:flutter/material.dart';
import '../../core/models/member.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/attendance_service.dart';
import '../../services/members_service.dart';

/// Alta de eventos en la colección `attendance_events` (modelo usado por reporte de faltas).
class CrearAttendanceEventScreen extends StatefulWidget {
  const CrearAttendanceEventScreen({super.key});

  @override
  State<CrearAttendanceEventScreen> createState() =>
      _CrearAttendanceEventScreenState();
}

class _CrearAttendanceEventScreenState extends State<CrearAttendanceEventScreen> {
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _lugarController = TextEditingController();
  final AttendanceService _service = AttendanceService();

  DateTime _fecha = DateTime.now();
  String _tipo = 'reunion';
  bool _loading = false;

  /// `true`: `miembrosConvocados` vacío → reporte usa todos los activos (`AttendanceService`).
  bool _convocatoriaTodosActivos = true;
  final Set<String> _miembrosConvocadosIds = <String>{};

  static const _tipos = <String, String>{
    'reunion': 'Reunión',
    'asamblea': 'Asamblea',
    'capacitacion': 'Capacitación',
    'ordinaria': 'Ordinaria',
    'extraordinaria': 'Extraordinaria',
  };

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _lugarController.dispose();
    super.dispose();
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
    });
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
          child: _SeleccionConvocadosSheet(initial: {..._miembrosConvocadosIds}),
        );
      },
    );
    if (nueva != null && mounted) {
      setState(() => _miembrosConvocadosIds
        ..clear()
        ..addAll(nueva));
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

    setState(() => _loading = true);
    try {
      final eventId = await _service.createEvent(
        AttendanceEvent(
          id: '',
          nombre: nombre,
          descripcion: _descripcionController.text.trim(),
          fecha: _fecha.millisecondsSinceEpoch,
          lugar: lugar,
          tipo: _tipo,
          activo: true,
          miembrosConvocados:
              _convocatoriaTodosActivos ? [] : _miembrosConvocadosIds.toList(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
        title: 'Nuevo evento (reporte)',
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
                      'Modelo Firestore',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Se guarda en attendance_events para el reporte de presentes y faltantes. '
                      'Con «Todos los socios activos», la lista convocada se deja vacía y el '
                      'reporte incluye todos los socios activos del padrón.',
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
              children: _tipos.entries.map((e) {
                final selected = _tipo == e.key;
                return FilterChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: (_) => setState(() => _tipo = e.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha y hora'),
              subtitle: Text(
                '${_fecha.day}/${_fecha.month}/${_fecha.year} '
                '${_fecha.hour.toString().padLeft(2, '0')}:'
                '${_fecha.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDateTime,
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
                            onPressed: () =>
                                Navigator.pop(context, _seleccion),
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
