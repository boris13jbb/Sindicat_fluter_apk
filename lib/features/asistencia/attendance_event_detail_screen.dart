import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/attendance_service.dart';
import '../../core/utils/date_time_ms.dart';
import '../elections/widgets/voto_premium_chrome.dart';
import 'route_args.dart';

String _detailFmt(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _detailMetaLine(int fechaMs, String lugar) {
  final d = DateTime.fromMillisecondsSinceEpoch(fechaMs);
  final dateStr =
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  final timeStr =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final l = lugar.trim().isEmpty ? 'Sin lugar' : lugar.trim();
  return '$l · $dateStr · $timeStr';
}

/// Detalle y operaciones para un doc en colección **`attendance_events`**
/// (`04_asistencia_detalle_evento` — layout premium).
class AttendanceEventDetailScreen extends StatefulWidget {
  const AttendanceEventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<AttendanceEventDetailScreen> createState() =>
      _AttendanceEventDetailScreenState();
}

class _AttendanceEventDetailScreenState
    extends State<AttendanceEventDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final eventId = widget.eventId;
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

    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? UserRole.user;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      bottomNavigationBar: VotoModuleBottomNavigation(
        role: role,
        selection: VotoNavSlot.asistencia,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('attendance_events')
            .doc(eventId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error: ${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VotoWaveHeader(
                  title: 'Detalle del evento',
                  subtitle: 'Cargando…',
                  onBack: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Cargando evento…'),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          final map = snap.data!.data() ?? {};
          final nombre = map['nombre'] as String? ?? '(sin nombre)';
          final fecha = (map['fecha'] as num?)?.toInt() ?? 0;
          final fechaFin = (map['fechaFin'] as num?)?.toInt();
          final lugar = map['lugar'] as String? ?? '';
          final desc = map['descripcion'] as String?;
          final activo = map['activo'] as bool? ?? true;
          final estado = (map['estado'] as String? ?? 'programado')
              .toLowerCase()
              .trim();
          final modalidadesRaw = List<String>.from(
            map['modalidadesNoConvocadas'] ?? [],
          );
          final modalidadesEtiquetas = modalidadesRaw
              .map(Modalidad.tryParse)
              .whereType<Modalidad>()
              .map(JustificacionHelper.etiquetaModalidad)
              .toList();

          final ahora = DateTime.now().millisecondsSinceEpoch;
          final finMs = fechaFin ?? endOfLocalDayMs(fecha);
          final bool operativo =
              activo && estado != 'finalizado' && finMs >= ahora;
          final bool badgeActivo = operativo;
          final bool qrHabilitado = activo && estado != 'finalizado';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VotoWaveHeader(
                title: 'Detalle del evento',
                subtitle: nombre,
                onBack: () => Navigator.pop(context),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VotoCircleIconButton(
                      icon: Icons.tune_rounded,
                      onTap: openModalidadesEditor,
                    ),
                    const SizedBox(width: 6),
                    VotoCircleIconButton(
                      icon: Icons.share_outlined,
                      onTap: () {
                        Share.share(
                          'Evento: $nombre\n'
                          'Inicio: ${_detailFmt(fecha)}\n'
                          'ID: $eventId',
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    VotoCircleIconButton(
                      icon: Icons.more_horiz_rounded,
                      onTap: () {
                        showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          backgroundColor: AppDesignTokens.background,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.home_work_outlined),
                                  title: const Text(
                                    'Ir al inicio de asistencia',
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Navigator.of(
                                      context,
                                    ).pushNamedAndRemoveUntil(
                                      '/asistencia',
                                      (route) => route.isFirst,
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.copy_outlined),
                                  title: const Text('Copiar ID del evento'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Clipboard.setData(
                                      ClipboardData(text: eventId),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'ID copiado al portapapeles',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (desc != null && desc.isNotEmpty)
                                  ListTile(
                                    leading: const Icon(Icons.notes_outlined),
                                    title: Text(
                                      desc,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (fechaFin != null)
                                  ListTile(
                                    leading: const Icon(Icons.event_outlined),
                                    title: Text('Fin: ${_detailFmt(fechaFin)}'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDesignTokens.horizontalPadding,
                    12,
                    AppDesignTokens.horizontalPadding,
                    24,
                  ),
                  children: [
                    PremiumCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignTokens.primaryDark,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _detailMetaLine(fecha, lugar),
                            style: AppDesignTokens.bodyMuted(context),
                          ),
                          if (desc != null && desc.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              desc.trim(),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppDesignTokens.primaryDark
                                        .withValues(alpha: 0.75),
                                  ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatusChip(
                                label: badgeActivo ? 'Activo' : 'No activo',
                                fg: badgeActivo
                                    ? Colors.green.shade900
                                    : Colors.blueGrey.shade800,
                                bg: badgeActivo
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFF1F3F8),
                              ),
                              _StatusChip(
                                label: qrHabilitado
                                    ? 'QR habilitado'
                                    : 'QR no disponible',
                                fg: AppDesignTokens.primaryDark,
                                bg: AppDesignTokens.lavanda,
                              ),
                            ],
                          ),
                          if (modalidadesEtiquetas.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Modalidades no convocadas',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignTokens.primaryDark,
                                  ),
                            ),
                            const SizedBox(height: 6),
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
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<AttendanceHubDashboardData?>(
                      future: attendanceSvc.buildHubDashboardData(eventId),
                      builder: (context, hubSnap) {
                        final data = hubSnap.data;
                        final loading =
                            hubSnap.connectionState ==
                                ConnectionState.waiting &&
                            !hubSnap.hasData;
                        return Row(
                          children: [
                            Expanded(
                              child: _MiniStatCell(
                                label: 'Presentes',
                                value: loading
                                    ? '…'
                                    : data != null
                                    ? '${data.presentes}'
                                    : '—',
                                valueColor: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniStatCell(
                                label: 'Ausentes',
                                value: loading
                                    ? '…'
                                    : data != null
                                    ? '${data.ausentes}'
                                    : '—',
                                valueColor: Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniStatCell(
                                label: 'Avance',
                                value: loading
                                    ? '…'
                                    : data != null && data.totalConvocados > 0
                                    ? '${data.porcentajePresentes.round()}%'
                                    : '—',
                                valueColor: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Opciones del evento',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppDesignTokens.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _EventOptionTile(
                      title: 'Escanear QR',
                      subtitle: 'Registrar con cámara',
                      icon: Icons.qr_code_scanner_rounded,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/asistencia/scanner',
                        arguments: AsistenciaEventRouteArgs.attendance(
                          eventId,
                          openScannerDirectly: true,
                        ),
                      ),
                    ),
                    _EventOptionTile(
                      title: 'Registro manual',
                      subtitle: 'Buscar y marcar persona',
                      icon: Icons.check_circle_outline_rounded,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/asistencia/registro_manual',
                        arguments: AsistenciaEventRouteArgs.attendance(eventId),
                      ),
                    ),
                    _EventOptionTile(
                      title: 'Ver asistencias',
                      subtitle: 'Listado del evento',
                      icon: Icons.format_list_bulleted_rounded,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/asistencia/evento_registros',
                        arguments: eventId,
                      ),
                    ),
                    _EventOptionTile(
                      title: 'Reporte',
                      subtitle: 'Estadísticas y exportación',
                      icon: Icons.bar_chart_rounded,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/attendance/report',
                        arguments: eventId,
                      ),
                    ),
                    _EventOptionTile(
                      title: 'Códigos QR',
                      subtitle: 'Credenciales del evento',
                      icon: Icons.qr_code_2_outlined,
                      onTap: () =>
                          Navigator.pushNamed(context, '/asistencia/qr_codes'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.fg, required this.bg});

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MiniStatCell extends StatelessWidget {
  const _MiniStatCell({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppDesignTokens.bodyMuted(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EventOptionTile extends StatelessWidget {
  const _EventOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppDesignTokens.primary.withValues(alpha: 0.12),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.lavanda,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppDesignTokens.primaryDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppDesignTokens.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppDesignTokens.bodyMuted(context)),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppDesignTokens.primary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
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
          modalidadesNoConvocadas: _selected.map((m) => m.value).toList(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modalidades no convocadas actualizadas')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
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
              children: Modalidad.valoresParaJustificacionAsistencia.map((
                modalidad,
              ) {
                final on = _selected.contains(modalidad);
                return FilterChip(
                  selected: on,
                  label: Text(JustificacionHelper.etiquetaModalidad(modalidad)),
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
