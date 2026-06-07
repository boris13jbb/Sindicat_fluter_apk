import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/models/member.dart';
import '../../services/attendance_service.dart';
import '../../services/members_service.dart';

/// Listado premium de registros (`attendance_events/{id}/asistencias`).
class AttendanceEventRecordsList extends StatefulWidget {
  const AttendanceEventRecordsList({
    super.key,
    required this.eventId,
    required this.attendanceSvc,
    this.searchQuery = '',
    this.physics,
    this.padding = EdgeInsets.zero,
    this.scrollController,
    this.shrinkWrap = false,
  });

  final String eventId;
  final AttendanceService attendanceSvc;

  /// Filtro en cliente por nombre visible, número de socio, código o id.
  final String searchQuery;

  /// Control de scroll externos (nested scroll opcional).
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  /// Si se proporciona y [physics] permite, úsalo desde el padre.
  final ScrollController? scrollController;

  /// `true` dentro de scrolls anidados con altura indefinida.
  final bool shrinkWrap;

  @override
  State<AttendanceEventRecordsList> createState() =>
      _AttendanceEventRecordsListState();
}

class _AttendanceEventRecordsListState
    extends State<AttendanceEventRecordsList> {
  final MembersService _membersService = MembersService();
  final Map<String, Member?> _memberByPersonaId = {};
  final Set<String> _loadingPersonaIds = {};

  static String _fmtHoraMin(int? ms) {
    if (ms == null || ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  static String _fmtRegistroDetallado(int? ms) {
    if (ms == null || ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  static String _metodoCorto(MetodoRegistro m) {
    switch (m) {
      case MetodoRegistro.escaneoQr:
        return 'QR';
      case MetodoRegistro.escaneoBarcode:
        return 'Barra';
      case MetodoRegistro.manual:
        return 'Manual';
    }
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
      if (_memberByPersonaId.containsKey(id) ||
          _loadingPersonaIds.contains(id)) {
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

  bool _matchesQuery(AsistenciaRegistro r, String q) {
    if (q.trim().isEmpty) return true;
    final query = q.toLowerCase().trim();
    if (r.personaId.toLowerCase().contains(query)) return true;
    final m = _memberByPersonaId[r.personaId];
    if (m != null) {
      if (m.fullName.toLowerCase().contains(query)) return true;
      if (m.memberNumber.toLowerCase().contains(query)) return true;
      if (m.workerCode?.toLowerCase().contains(query) == true) return true;
      if (m.documentId?.toLowerCase().contains(query) == true) return true;
    }
    return false;
  }

  void _openDetalle(
    BuildContext context,
    AsistenciaRegistro r,
    Member? member,
    bool loading,
    bool noEnPadron,
    String nombreMostrado,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final estadoTxt = r.asistio ? 'Asistió' : 'No asistió';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppDesignTokens.background,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombreMostrado, style: AppDesignTokens.titleLarge(ctx)),
                const SizedBox(height: 8),
                Text(
                  '$estadoTxt • ${_fmtRegistroDetallado(r.fechaRegistro)}'
                  '${r.metodoRegistro == MetodoRegistro.manual ? '' : ' · ${r.metodoRegistro.value}'}',
                  style: AppDesignTokens.bodyMuted(ctx),
                ),
                if (r.justificacion?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    r.justificacion!.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (!loading && member != null) ...[
                  const SizedBox(height: 16),
                  _metaRow(
                    ctx,
                    Icons.badge_outlined,
                    'N° Socio',
                    member.memberNumber,
                  ),
                  if (member.documentId?.trim().isNotEmpty == true)
                    _metaRow(
                      ctx,
                      Icons.credit_card_outlined,
                      'Cédula',
                      member.documentId!,
                    ),
                  _metaRow(
                    ctx,
                    Icons.schedule_outlined,
                    'Modalidad',
                    member.modalidad != null
                        ? JustificacionHelper.etiquetaModalidad(
                            member.modalidad!,
                          )
                        : 'Sin asignar',
                  ),
                ] else if (r.personaId.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'El registro no tiene personaId. Revise el guardado en Firestore.',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                  ),
                ] else if (noEnPadron) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Referencia en registro: ${r.personaId}\n'
                    'No hay coincidencia en el padrón por id de documento, '
                    'código trabajador o número de socio.',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                  ),
                ] else if (loading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(minHeight: 4),
                ],
              ],
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<AsistenciaRegistro>>(
      stream: widget.attendanceSvc.getEventAttendances(widget.eventId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final list = snap.data;
        if (list == null) {
          return Center(
            child: CircularProgressIndicator(color: AppDesignTokens.primary),
          );
        }

        _scheduleLoadsFor(list);

        final filtered = [
          for (final r in list)
            if (_matchesQuery(r, widget.searchQuery)) r,
        ];

        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Sin registros.\n\n'
                'Usa Escanear QR o Registro manual en el detalle del evento.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          );
        }

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No hay coincidencias con «${widget.searchQuery}»',
                textAlign: TextAlign.center,
                style: AppDesignTokens.bodyMuted(context),
              ),
            ),
          );
        }

        return ListView.separated(
          controller: widget.scrollController,
          shrinkWrap: widget.shrinkWrap,
          physics:
              widget.physics ??
              (widget.shrinkWrap
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics()),
          padding: widget.padding,
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = filtered[i];
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

            final ok = r.asistio;
            final green = const Color(0xFF27AE60);
            final red = const Color(0xFFE74C3C);
            final leadTint = ok
                ? green.withValues(alpha: 0.12)
                : red.withValues(alpha: 0.12);
            final iconColor = ok ? green : red;
            final sub = ok
                ? '${_fmtHoraMin(r.fechaRegistro)} · ${_metodoCorto(r.metodoRegistro)}'
                : 'Pendiente';

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openDetalle(
                  context,
                  r,
                  member,
                  loading,
                  noEnPadron,
                  nombreMostrado,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6E9EF)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: leadTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.people_outline_rounded,
                            color: iconColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombreMostrado,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF2B2265),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ok ? green : red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            ok ? 'Presente' : 'Pendiente',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
