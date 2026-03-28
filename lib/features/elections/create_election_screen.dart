import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/election.dart';
import '../../core/models/user_role.dart';
import '../../core/models/asistencia/evento.dart';
import '../../providers/auth_provider.dart';
import '../../services/election_service.dart';
import '../../services/asistencia_service.dart';
import '../../core/widgets/professional_app_bar.dart';

class CreateElectionScreen extends StatefulWidget {
  const CreateElectionScreen({super.key});

  @override
  State<CreateElectionScreen> createState() => _CreateElectionScreenState();
}

class _CreateElectionScreenState extends State<CreateElectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _requireAttendance = false;
  String? _eventoAsistenciaId;
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return;
    final dt = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startDate = dt;
      } else {
        _endDate = dt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user?.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crear Elección')),
        body: const Center(
          child: Text('Solo administradores pueden crear elecciones.'),
        ),
      );
    }

    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Crear Elección',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Completa el formulario para crear la elección.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título de la Elección *',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción *',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _startDate == null
                      ? 'Fecha de Inicio *'
                      : 'Inicio: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year} ${_startDate!.hour.toString().padLeft(2, '0')}:${_startDate!.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(true),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(
                  _endDate == null
                      ? 'Fecha de Fin *'
                      : 'Fin: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year} ${_endDate!.hour.toString().padLeft(2, '0')}:${_endDate!.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(false),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Requerir asistencia'),
                subtitle: const Text(
                  'Solo quienes figuren en el evento de asistencia podrán votar',
                ),
                value: _requireAttendance,
                onChanged: (v) => setState(() {
                  _requireAttendance = v;
                  if (!v) _eventoAsistenciaId = null;
                }),
              ),
              if (_requireAttendance) ...[
                const SizedBox(height: 8),
                StreamBuilder<List<EventoAsistencia>>(
                  stream: AsistenciaService().getAllEventos(),
                  builder: (context, snap) {
                    final eventos = snap.data ?? [];
                    return DropdownButtonFormField<String?>(
                      initialValue: _eventoAsistenciaId,
                      decoration: const InputDecoration(
                        labelText: 'Evento de asistencia vinculado',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Seleccionar evento'),
                        ),
                        ...eventos.map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(
                              '${e.nombre} (${_formatEventDate(e.fecha)})',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _eventoAsistenciaId = v),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  onPressed: () async {
                    if (_formKey.currentState?.validate() != true) return;
                    if (_startDate == null || _endDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selecciona fechas de inicio y fin'),
                        ),
                      );
                      return;
                    }
                    if (_endDate!.isBefore(_startDate!)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'La fecha de fin debe ser posterior al inicio',
                          ),
                        ),
                      );
                      return;
                    }
                    if (_requireAttendance && _eventoAsistenciaId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Selecciona un evento de asistencia cuando requieras asistencia',
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() => _loading = true);
                    try {
                      final service = ElectionService();
                      final election = Election(
                        id: '',
                        title: _titleController.text.trim(),
                        description: _descriptionController.text.trim(),
                        startDate: _startDate!.millisecondsSinceEpoch,
                        endDate: _endDate!.millisecondsSinceEpoch,
                        isActive: true,
                        requireAttendance: _requireAttendance,
                        eventoAsistenciaId: _eventoAsistenciaId,
                        createdBy: user!.id,
                      );
                      await service.createElection(election);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Elección creada')),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
                  child: const Text('Crear Elección'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatEventDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year}';
  }
}
