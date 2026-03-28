import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/election.dart';
import '../../core/models/candidate.dart';
import '../../core/models/user_role.dart';
import '../../core/models/asistencia/evento.dart';
import '../../providers/auth_provider.dart';
import '../../services/election_service.dart';
import '../../services/asistencia_service.dart';
import '../../core/widgets/professional_app_bar.dart';

class EditElectionScreen extends StatefulWidget {
  const EditElectionScreen({super.key, required this.electionId});

  final String electionId;

  @override
  State<EditElectionScreen> createState() => _EditElectionScreenState();
}

class _EditElectionScreenState extends State<EditElectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _isVisibleToVoters = true;
  bool _showResultsAutomatically = true;
  bool _requireAttendance = false;
  String? _eventoAsistenciaId;
  bool _loading = false;
  bool _fetching = true;
  Election? _election;
  final ElectionService _electionService = ElectionService();

  @override
  void initState() {
    super.initState();
    _loadElection();
  }

  Future<void> _loadElection() async {
    final service = ElectionService();
    final election = await service.getElection(widget.electionId);
    if (mounted) {
      if (election != null) {
        setState(() {
          _election = election;
          _titleController.text = election.title;
          _descriptionController.text = election.description;
          _startDate = DateTime.fromMillisecondsSinceEpoch(election.startDate);
          _endDate = DateTime.fromMillisecondsSinceEpoch(election.endDate);
          _isActive = election.isActive;
          _isVisibleToVoters = election.isVisibleToVoters;
          _showResultsAutomatically = election.showResultsAutomatically;
          _requireAttendance = election.requireAttendance;
          _eventoAsistenciaId = election.eventoAsistenciaId;
          _fetching = false;
        });
      } else {
        Navigator.pop(context);
      }
    }
  }

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
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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
      return const Scaffold(body: Center(child: Text('Acceso denegado')));
    }

    if (_fetching) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Editar Elección',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                ),
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _startDate == null
                      ? 'Fecha Inicio'
                      : 'Inicio: ${_startDate.toString().substring(0, 16)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(true),
              ),
              ListTile(
                title: Text(
                  _endDate == null
                      ? 'Fecha Fin'
                      : 'Fin: ${_endDate.toString().substring(0, 16)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(false),
              ),
              SwitchListTile(
                title: const Text('Elección Activa'),
                subtitle: const Text('Permite recibir votos si está en fecha'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              SwitchListTile(
                title: const Text('Visible para Votantes'),
                value: _isVisibleToVoters,
                onChanged: (v) => setState(() => _isVisibleToVoters = v),
              ),
              SwitchListTile(
                title: const Text('Mostrar resultados automáticamente'),
                subtitle: const Text(
                  'Al finalizar, los votantes pueden ver resultados',
                ),
                value: _showResultsAutomatically,
                onChanged: (v) => setState(() => _showResultsAutomatically = v),
              ),
              SwitchListTile(
                title: const Text('Requerir asistencia'),
                subtitle: const Text(
                  'Solo quienes figuren en el evento podrán votar',
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
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    final eventos = snap.data ?? [];
                    // Validate that _eventoAsistenciaId exists in the events list
                    final isValidValue =
                        _eventoAsistenciaId == null ||
                        eventos.any((e) => e.id == _eventoAsistenciaId);
                    
                    return DropdownButtonFormField<String?>(
                      value: isValidValue ? _eventoAsistenciaId : null,
                      decoration: const InputDecoration(
                        labelText: 'Evento de asistencia',
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
                            child: Text(e.nombre),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _eventoAsistenciaId = v),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Candidatos',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Candidate>>(
                stream: _electionService.getCandidates(widget.electionId),
                builder: (context, snap) {
                  // Debug logging
                  debugPrint(
                    'EditElection StreamBuilder: ConnectionState = ${snap.connectionState}',
                  );

                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    debugPrint(
                      'EditElection StreamBuilder: ERROR - ${snap.error}',
                    );
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error al cargar candidatos: ${snap.error}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  }
                  
                  final candidates = snap.data ?? [];
                  debugPrint(
                    'EditElection StreamBuilder: ${candidates.length} candidatos cargados',
                  );

                  if (candidates.isEmpty) {
                    return Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        const Text('No hay candidatos registrados'),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  
                  return Column(
                    children: [
                      ...candidates.map(
                        (c) => _CandidateEditTile(
                          candidate: c,
                          onEdit: () => _showEditCandidateDialog(context, c),
                          onDelete: () => _confirmDeleteCandidate(context, c),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/voto/add_candidate',
                          arguments: widget.electionId,
                        ),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Agregar Candidato'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  onPressed: _handleUpdate,
                  child: const Text('Guardar Cambios'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_startDate == null || _endDate == null) return;

    setState(() => _loading = true);
    try {
      final updated = _election!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startDate: _startDate!.millisecondsSinceEpoch,
        endDate: _endDate!.millisecondsSinceEpoch,
        isActive: _isActive,
        isVisibleToVoters: _isVisibleToVoters,
        showResultsAutomatically: _showResultsAutomatically,
        requireAttendance: _requireAttendance,
        eventoAsistenciaId: _eventoAsistenciaId,
      );
      await _electionService.updateElection(updated);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Elección actualizada')));
        Navigator.pop(context);
      }
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

  void _showEditCandidateDialog(BuildContext context, Candidate c) {
    final nameController = TextEditingController(text: c.name);
    final descController = TextEditingController(text: c.description ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Candidato'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await _electionService.updateCandidate(
                c.copyWith(
                  name: nameController.text.trim(),
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                ),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Candidato actualizado')),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCandidate(
    BuildContext context,
    Candidate c,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar candidato'),
        content: Text(
          '¿Eliminar a "${c.name}"? Se perderán sus votos asociados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _electionService.deleteCandidate(widget.electionId, c.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Candidato eliminado')));
      }
    }
  }
}

class _CandidateEditTile extends StatelessWidget {
  const _CandidateEditTile({
    required this.candidate,
    required this.onEdit,
    required this.onDelete,
  });

  final Candidate candidate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(candidate.name),
        subtitle:
            candidate.description != null && candidate.description!.isNotEmpty
            ? Text(
                candidate.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
            IconButton(
              icon: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
