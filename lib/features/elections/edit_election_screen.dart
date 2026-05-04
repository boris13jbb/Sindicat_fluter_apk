import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/models/election.dart';
import '../../core/models/candidate.dart';
import '../../core/models/user_role.dart';
import '../../core/models/asistencia/evento_asistencia_vinculo_eleccion.dart';
import '../../providers/auth_provider.dart';
import '../../services/election_service.dart';
import '../../services/candidate_photo_storage_service.dart';
import '../../services/asistencia_service.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import 'widgets/voto_premium_chrome.dart';
import 'candidate_image_upload_section.dart';

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
  List<Candidate> _initialCandidates = [];
  final ElectionService _electionService = ElectionService();
  final AsistenciaService _asistenciaService = AsistenciaService();
  late final Stream<List<EventoAsistenciaVinculoEleccion>>
      _eventosVinculoStream =
      _asistenciaService.watchEventosParaVinculoEleccion();

  @override
  void initState() {
    super.initState();
    _loadElection();
  }

  Future<void> _loadElection() async {
    final boot = await _electionService.loadResultsBootstrap(widget.electionId);
    if (!mounted) return;
    final election = boot.election;
    if (election != null) {
      setState(() {
        _election = election;
        _initialCandidates = boot.candidates;
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
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return;
    if (!mounted) return;
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

  String _formatDateTimeHuman(DateTime? d) {
    if (d == null) return 'Seleccionar';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _premiumSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppDesignTokens.lavanda.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppDesignTokens.primary.withValues(alpha: 0.1),
        ),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppDesignTokens.primaryDark,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppDesignTokens.primaryDark.withValues(alpha: 0.55),
            height: 1.25,
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final role = user?.role ?? UserRole.voter;
    final isAdmin =
        user?.role == UserRole.admin || user?.role == UserRole.superadmin;
    final mq = MediaQuery.of(context);
    final scrollBottomPad =
        24 + mq.viewPadding.bottom + mq.viewInsets.bottom + 80;

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppDesignTokens.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VotoWaveHeader(
              title: 'Editar elección',
              subtitle: 'Acceso restringido',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDesignTokens.horizontalPadding),
                  child: PremiumCard(
                    margin: EdgeInsets.zero,
                    child: Text(
                      'Acceso denegado',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppDesignTokens.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_fetching) {
      return Scaffold(
        backgroundColor: AppDesignTokens.background,
        bottomNavigationBar: VotoModuleBottomNavigation(role: role),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VotoWaveHeader(
              title: 'Editar elección',
              subtitle: 'Cargando datos…',
              onBack: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    final electionTitle = _election?.title.trim() ?? '';
    final headerSubtitle =
        electionTitle.isEmpty ? 'Datos y candidatos' : electionTitle;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      bottomNavigationBar: VotoModuleBottomNavigation(role: role),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Editar elección',
            subtitle: headerSubtitle,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppDesignTokens.horizontalPadding,
                14,
                AppDesignTokens.horizontalPadding,
                scrollBottomPad,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PremiumCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Datos principales',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignTokens.primaryDark,
                                ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _titleController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: votoPremiumInputDecoration(
                              'Título de la elección *',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: votoPremiumInputDecoration('Descripción *'),
                            maxLines: 3,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => _pickDate(true),
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: votoPremiumInputDecoration('Fecha inicio'),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatDateTimeHuman(_startDate),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppDesignTokens.primaryDark,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.event_rounded,
                                    color: AppDesignTokens.primaryDark
                                        .withValues(alpha: 0.45),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => _pickDate(false),
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: votoPremiumInputDecoration('Fecha fin'),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatDateTimeHuman(_endDate),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppDesignTokens.primaryDark,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.event_rounded,
                                    color: AppDesignTokens.primaryDark
                                        .withValues(alpha: 0.45),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    PremiumCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Reglas y visibilidad',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignTokens.primaryDark,
                                ),
                          ),
                          const SizedBox(height: 10),
                          _premiumSwitchTile(
                            title: 'Elección activa',
                            subtitle:
                                'Permite recibir votos cuando corresponda por fechas y estado.',
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                          _premiumSwitchTile(
                            title: 'Visible para votantes',
                            subtitle: 'Si está desactivada, no aparece en el listado público.',
                            value: _isVisibleToVoters,
                            onChanged: (v) => setState(() => _isVisibleToVoters = v),
                          ),
                          _premiumSwitchTile(
                            title: 'Mostrar resultados automáticamente',
                            subtitle:
                                'Al finalizar, los votantes pueden consultar estadísticas cuando las reglas lo permitan.',
                            value: _showResultsAutomatically,
                            onChanged: (v) =>
                                setState(() => _showResultsAutomatically = v),
                          ),
                          _premiumSwitchTile(
                            title: 'Requiere asistencia habilitante',
                            subtitle:
                                'Solo quienes figuren en el evento podrán votar.',
                            value: _requireAttendance,
                            onChanged: (v) => setState(() {
                              _requireAttendance = v;
                              if (!v) _eventoAsistenciaId = null;
                            }),
                          ),
                          if (_requireAttendance) ...[
                            const SizedBox(height: 6),
                            StreamBuilder<List<EventoAsistenciaVinculoEleccion>>(
                              stream: _eventosVinculoStream,
                              builder: (context, snap) {
                                if (snap.connectionState == ConnectionState.waiting &&
                                    !snap.hasData) {
                                  return const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                final eventos = snap.data ?? [];
                                final isValidValue =
                                    _eventoAsistenciaId == null ||
                                    eventos.any((e) => e.id == _eventoAsistenciaId);

                                return DropdownButtonFormField<String?>(
                                  isExpanded: true,
                                  initialValue:
                                      isValidValue ? _eventoAsistenciaId : null,
                                  decoration:
                                      votoPremiumInputDecoration(
                                    'Evento de asistencia vinculado',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text(
                                        'Seleccionar evento',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    ...eventos.map(
                                      (e) => DropdownMenuItem<String?>(
                                        value: e.id,
                                        child: Text(
                                          '${e.nombre} (${_formatEventDateTime(e.fechaInicioMs)}'
                                          ' – ${_formatEventDateTime(e.fechaFinMs)})'
                                          '${e.esLegacy ? ' · histórico' : ''}',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _eventoAsistenciaId = v),
                                );
                              },
                            ),
                          ],
                          const Divider(height: 32),
                          Text(
                            'Candidatos',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignTokens.primaryDark,
                                ),
                          ),
                          const SizedBox(height: 10),
                          StreamBuilder<List<Candidate>>(
                            stream: _electionService.getCandidates(widget.electionId),
                            initialData: _initialCandidates,
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting &&
                                  !snap.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }

                              if (snap.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    'Error al cargar candidatos: ${snap.error}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                );
                              }

                              final candidates = snap.data ?? [];

                              if (candidates.isEmpty) {
                                return Column(
                                  children: [
                                    Icon(
                                      Icons.groups_2_outlined,
                                      size: 44,
                                      color: AppDesignTokens.primary
                                          .withValues(alpha: 0.35),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No hay candidatos registrados.',
                                      style: AppDesignTokens.bodyMuted(context),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        '/voto/add_candidate',
                                        arguments: widget.electionId,
                                      ),
                                      icon: const Icon(Icons.person_add_rounded),
                                      label: const Text('Agregar candidato'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppDesignTokens.primary,
                                        side: BorderSide(
                                          color: AppDesignTokens.primary
                                              .withValues(alpha: 0.55),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  ...candidates.map(
                                    (c) => _CandidateEditTile(
                                      candidate: c,
                                      onEdit: () =>
                                          _showEditCandidateDialog(context, c),
                                      onDelete: () =>
                                          _confirmDeleteCandidate(context, c),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      '/voto/add_candidate',
                                      arguments: widget.electionId,
                                    ),
                                    icon: const Icon(Icons.person_add_rounded),
                                    label: const Text('Agregar candidato'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppDesignTokens.primary,
                                      side: BorderSide(
                                        color: AppDesignTokens.primary
                                            .withValues(alpha: 0.55),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 22),
                          if (_loading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else
                            FilledButton(
                              onPressed: _handleUpdate,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppDesignTokens.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Guardar cambios',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdate() async {
    if (_formKey.currentState?.validate() != true) return;
    final scheduleError = validateElectionDateRange(
      startDate: _startDate,
      endDate: _endDate,
    );
    if (scheduleError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(scheduleError)));
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

  Future<void> _showEditCandidateDialog(
    BuildContext context,
    Candidate c,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: c.name);
    final descController = TextEditingController(text: c.description ?? '');
    final imageUrlController = TextEditingController(text: c.imageUrl ?? '');
    final orderController = TextEditingController(text: c.order.toString());
    final stagedPickNotifier = ValueNotifier<XFile?>(null);

    final baselineImageUrl = (c.imageUrl ?? '').trim();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) {
        var saving = false;

        Future<void> doSave(StateSetter setModal) async {
          if (formKey.currentState?.validate() != true) return;
          if (saving) return;

          final selectedImageFile = stagedPickNotifier.value;
          final trimmedManual = imageUrlController.text.trim();
          final oldImageUrl = baselineImageUrl;

          debugPrint('===== GUARDAR CANDIDATO =====');
          debugPrint('modo: editar');
          debugPrint('electionId: ${c.electionId}');
          debugPrint('candidateId: ${c.id}');
          debugPrint(
            'selectedImageFile: ${selectedImageFile?.path}',
          );
          debugPrint('manualUrl: ${imageUrlController.text}');
          debugPrint('oldImageUrl: $oldImageUrl');

          setModal(() => saving = true);
          try {
            final photo = CandidatePhotoStorage();
            String? imageUrlToPersist;

            if (selectedImageFile != null) {
              imageUrlToPersist = await photo.uploadCandidateImage(
                electionId: c.electionId,
                candidateId: c.id,
                imageFile: selectedImageFile,
              );
            } else {
              debugPrint(
                'Sin archivo nuevo: no se usa Storage (ni getDownloadURL ni refFromURL).',
              );
              imageUrlToPersist =
                  trimmedManual.isEmpty ? null : trimmedManual;
            }

            await _electionService.updateCandidate(
              Candidate(
                id: c.id,
                electionId: c.electionId,
                name: nameController.text.trim(),
                description: descController.text.trim().isEmpty
                    ? null
                    : descController.text.trim(),
                imageUrl: imageUrlToPersist,
                order: parseCandidateOrder(orderController.text),
                voteCount: c.voteCount,
              ),
            );

            if (selectedImageFile != null) {
              // No limpiar el notifier antes del pop: dispara listeners/setState en
              // CandidateImageUploadSection durante el cierre de la ruta.
              final prev = oldImageUrl.trim();
              final next = (imageUrlToPersist ?? '').trim();
              if (prev.startsWith('https://') &&
                  prev.isNotEmpty &&
                  prev != next) {
                await CandidatePhotoStorage.tryDeleteOldCandidateImage(
                  oldImageUrl,
                );
              }
            }

            if (!dialogCtx.mounted) return;
            // No llamar setModal aquí: un rebuild del StatefulBuilder seguido del
            // pop provoca carreras y el assert _dependents.isEmpty al desmontar.
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Candidato actualizado correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(dialogCtx);
          } catch (e, st) {
            debugPrint('ERROR GUARDANDO CANDIDATO: $e');
            debugPrint('STACKTRACE: $st');
            if (dialogCtx.mounted) {
              setModal(() => saving = false);
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error al guardar: $e')),
              );
            }
          }
        }

        return StatefulBuilder(
          builder: (ctx, setModal) {
            return AlertDialog(
              title: const Text('Editar Candidato'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (saving) ...[
                        const LinearProgressIndicator(minHeight: 3),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: nameController,
                        decoration:
                            const InputDecoration(labelText: 'Nombre'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        decoration:
                            const InputDecoration(labelText: 'Descripción'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      CandidateImageUploadSection(
                        electionId: c.electionId,
                        urlController: imageUrlController,
                        stagedPickNotifier: stagedPickNotifier,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: orderController,
                        decoration: const InputDecoration(
                          labelText: 'Orden en lista',
                          prefixIcon: Icon(Icons.sort),
                        ),
                        keyboardType: TextInputType.number,
                        validator: validateCandidateOrder,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: saving ? null : () => doSave(setModal),
                  child: Text(saving ? 'Guardando…' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
    } finally {
      nameController.dispose();
      descController.dispose();
      imageUrlController.dispose();
      orderController.dispose();
      stagedPickNotifier.dispose();
    }
  }

  Future<void> _confirmDeleteCandidate(
    BuildContext context,
    Candidate c,
  ) async {
    if (c.voteCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
            'El candidato "${c.name}" tiene ${c.voteCount} voto(s) registrados. '
            'Para conservar la trazabilidad del resultado, no se permite eliminarlo.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar candidato'),
        content: Text(
          '¿Eliminar a "${c.name}"? Esta acción no se puede deshacer.',
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
      try {
        await _electionService.deleteCandidate(widget.electionId, c.id);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Candidato eliminado')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  static String _formatEventDateTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
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
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: ListTile(
        title: Text(
          candidate.name,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppDesignTokens.primaryDark,
          ),
        ),
        subtitle:
            candidate.description != null && candidate.description!.isNotEmpty
                ? Text(
                    candidate.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppDesignTokens.primaryDark.withValues(alpha: 0.55),
                    ),
                  )
                : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              color: AppDesignTokens.primary,
              onPressed: onEdit,
              tooltip: 'Editar',
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: onDelete,
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }
}
