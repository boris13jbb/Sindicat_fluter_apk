import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/election.dart';
import '../../core/models/user_role.dart';
import '../../core/models/asistencia/evento_asistencia_vinculo_eleccion.dart';
import '../../providers/auth_provider.dart';
import '../../services/election_service.dart';
import '../../services/asistencia_service.dart';
import 'widgets/voto_premium_chrome.dart';

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
  bool _showResultsAutomatically = true;
  bool _isVisibleToVoters = true;
  String? _eventoAsistenciaId;
  bool _loading = false;
  final AsistenciaService _asistenciaService = AsistenciaService();
  late final Stream<List<EventoAsistenciaVinculoEleccion>>
      _eventosVinculoStream =
      _asistenciaService.watchEventosParaVinculoEleccion();

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

  String _formatDateTime(DateTime? d) {
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
    final isAdmin =
        user?.role == UserRole.admin || user?.role == UserRole.superadmin;
    final role = user?.role ?? UserRole.voter;

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppDesignTokens.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VotoWaveHeader(
              title: 'Crear elección',
              subtitle: 'Nueva votación',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDesignTokens.horizontalPadding),
                  child: PremiumCard(
                    margin: EdgeInsets.zero,
                    child: Text(
                      'Solo administradores pueden crear elecciones.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppDesignTokens.primaryDark,
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

    final mq = MediaQuery.of(context);
    final scrollBottomPad =
        24 + mq.viewPadding.bottom + mq.viewInsets.bottom + 80;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      bottomNavigationBar: VotoModuleBottomNavigation(role: role),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Crear elección',
            subtitle: 'Nueva votación',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppDesignTokens.horizontalPadding,
                16,
                AppDesignTokens.horizontalPadding,
                scrollBottomPad,
              ),
              child: Form(
                key: _formKey,
                child: PremiumCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Datos principales',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppDesignTokens.primaryDark,
                            ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: votoPremiumInputDecoration('Nombre'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: votoPremiumInputDecoration('Descripción'),
                        maxLines: 4,
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
                                  _formatDateTime(_startDate),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _startDate == null
                                        ? AppDesignTokens.primaryDark
                                            .withValues(alpha: 0.45)
                                        : AppDesignTokens.primaryDark,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                                color: AppDesignTokens.primary,
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
                          decoration: votoPremiumInputDecoration('Fecha cierre'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _formatDateTime(_endDate),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _endDate == null
                                        ? AppDesignTokens.primaryDark
                                            .withValues(alpha: 0.45)
                                        : AppDesignTokens.primaryDark,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.event_rounded,
                                size: 20,
                                color: AppDesignTokens.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Reglas',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppDesignTokens.primaryDark,
                            ),
                      ),
                      const SizedBox(height: 10),
                      _premiumSwitchTile(
                        title: 'Visible para votantes',
                        subtitle:
                            'Si está desactivada, la elección no aparece en el listado público.',
                        value: _isVisibleToVoters,
                        onChanged: (v) => setState(() => _isVisibleToVoters = v),
                      ),
                      _premiumSwitchTile(
                        title: 'Mostrar resultados en vivo',
                        subtitle:
                            'Permite ver estadísticas cuando la elección lo permita según fechas.',
                        value: _showResultsAutomatically,
                        onChanged: (v) =>
                            setState(() => _showResultsAutomatically = v),
                      ),
                      _premiumSwitchTile(
                        title: 'Requiere asistencia habilitante',
                        subtitle:
                            'Solo quienes figuren en el evento de asistencia podrán votar.',
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
                            final eventos = snap.data ?? [];
                            return DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: _eventoAsistenciaId,
                              decoration: votoPremiumInputDecoration(
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
                          onPressed: () async {
                            if (_formKey.currentState?.validate() != true) {
                              return;
                            }
                            final scheduleError = validateElectionDateRange(
                              startDate: _startDate,
                              endDate: _endDate,
                            );
                            if (scheduleError != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(scheduleError)),
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
                                isVisibleToVoters: _isVisibleToVoters,
                                showResultsAutomatically:
                                    _showResultsAutomatically,
                                requireAttendance: _requireAttendance,
                                eventoAsistenciaId: _eventoAsistenciaId,
                                createdBy: user!.id,
                              );
                              await service.createElection(election);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Elección creada'),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _loading = false);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppDesignTokens.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Guardar elección',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatEventDateTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
