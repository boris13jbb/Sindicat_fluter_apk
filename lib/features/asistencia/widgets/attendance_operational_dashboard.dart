import 'package:flutter/material.dart';

import '../../../services/attendance_service.dart';

/// Dashboard en tiempo casi real del evento operativo destacado (`attendance_events`).
class AttendanceOperationalDashboard extends StatelessWidget {
  const AttendanceOperationalDashboard({
    super.key,
    required this.service,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final AttendanceService service;
  final EdgeInsets padding;

  static String _fmtFecha(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: padding,
      child: StreamBuilder<List<AttendanceEvent>>(
        stream: service.getAllEvents(),
        builder: (context, evSnap) {
          if (evSnap.hasError) {
            return Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No se pudo cargar eventos: ${evSnap.error}',
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
            );
          }
          final events = evSnap.data ?? [];
          final id = AttendanceService.pickHighlightedOperationalEventId(events);
          if (id == null) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.insights_outlined, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard de asistencia',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No hay eventos activos. Crea uno para ver '
                            'presentes vs convocados en vivo.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder(
            stream: service.getEventAttendances(id),
            builder: (context, attSnap) {
              final sig = attSnap.hasData
                  ? attSnap.data!
                      .map((a) => '${a.id}_${a.asistio}_${a.fechaRegistro}')
                      .join('|')
                  : '';
              return FutureBuilder<AttendanceHubDashboardData?>(
                key: ValueKey('$id|$sig'),
                future: service.buildHubDashboardData(id),
                builder: (context, futSnap) {
                  if (futSnap.connectionState == ConnectionState.waiting &&
                      !futSnap.hasData) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Calculando asistencia del evento…',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final data = futSnap.data;
                  if (data == null) {
                    return const SizedBox.shrink();
                  }

                  final conv = data.totalConvocados;
                  final prog = conv > 0 ? data.presentes / conv : 0.0;

                  return Card(
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/asistencia/attendance_event_detail',
                        arguments: data.eventId,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.dashboard_customize_outlined,
                                    color: cs.primary, size: 26),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Evento en curso',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        data.nombre,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _fmtFecha(data.fechaMillis) +
                                            (data.lugar.trim().isEmpty
                                                ? ''
                                                : ' · ${data.lugar}'),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: cs.outline),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              conv > 0
                                  ? '${data.presentes} de $conv socios convocados'
                                  : data.presentes > 0
                                      ? '${data.presentes} presentes '
                                          '(sin convocatoria numérica)'
                                      : 'Sin socios en convocatoria obligatoria',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: prog.clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor:
                                    cs.surfaceContainerHighest.withValues(
                                        alpha: 0.85),
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _miniStat(
                                  context,
                                  Icons.check_circle_outline,
                                  'Presentes',
                                  '${data.presentes}',
                                  Colors.green.shade700,
                                ),
                                _miniStat(
                                  context,
                                  Icons.cancel_outlined,
                                  'Ausentes',
                                  '${data.ausentes}',
                                  cs.error,
                                ),
                                _miniStat(
                                  context,
                                  Icons.not_interested_outlined,
                                  'No convocados',
                                  '${data.noConvocadosModalidad}',
                                  cs.outline,
                                ),
                                _miniStat(
                                  context,
                                  Icons.percent_outlined,
                                  'Asistencia',
                                  conv > 0
                                      ? '${data.porcentajePresentes.toStringAsFixed(1)}%'
                                      : '—',
                                  cs.primary,
                                ),
                                _miniStat(
                                  context,
                                  Icons.list_alt_outlined,
                                  'Registros',
                                  '${data.totalRegistrosSubcoleccion}',
                                  cs.onSurfaceVariant,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Toca para abrir detalle, escanear o registro manual.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color tint,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: tint),
              ),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
