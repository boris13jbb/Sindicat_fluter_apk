import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/models/user.dart';
import '../../core/models/user_role.dart';
import '../elections/widgets/voto_premium_chrome.dart';
import '../home/widgets/dashboard_welcome_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../services/asistencia_service.dart';
import '../../services/attendance_service.dart';
import 'route_args.dart';

/// Inicio premium del módulo de asistencia (`13_inicio_asistencia`).
class AsistenciaHomeScreen extends StatefulWidget {
  const AsistenciaHomeScreen({super.key});

  @override
  State<AsistenciaHomeScreen> createState() => _AsistenciaHomeScreenState();
}

class _AsistenciaHomeScreenState extends State<AsistenciaHomeScreen> {
  final AsistenciaService _legacyService = AsistenciaService();
  final AttendanceService _attendanceService = AttendanceService();

  static String _formatFechaLarga(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const meses = <String>[
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${d.day} ${meses[d.month - 1]}';
  }

  static String _formatFechaHora(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  int _pendingOperationalCount(List<AttendanceEvent> events) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return events
        .where(
          (e) =>
              e.activo &&
              e.estado.toLowerCase().trim() != 'finalizado' &&
              e.fechaFinVigenciaMs >= now,
        )
        .length;
  }

  List<AttendanceEvent> _proximosEventos(List<AttendanceEvent> events) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final candidatos = events.where((e) => e.activo).where((e) {
      final fin = e.fechaFinVigenciaMs;
      final st = e.estado.toLowerCase().trim();
      if (st == 'en_curso') return true;
      if (st == 'finalizado') return false;
      return fin >= now;
    }).toList();
    candidatos.sort((a, b) => a.fecha.compareTo(b.fecha));
    return candidatos.take(2).toList();
  }

  void _onBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _openScannerWithHighlight(List<AttendanceEvent> events) {
    final id = AttendanceService.pickHighlightedOperationalEventId(events);
    if (id != null) {
      Navigator.pushNamed(
        context,
        '/asistencia/scanner',
        arguments: AsistenciaEventRouteArgs.attendance(id),
      );
    } else {
      Navigator.pushNamed(context, '/asistencia/scanner');
    }
  }

  void _openRegistroManualWithHighlight(List<AttendanceEvent> events) {
    final id = AttendanceService.pickHighlightedOperationalEventId(events);
    if (id != null) {
      Navigator.pushNamed(
        context,
        '/asistencia/registro_manual',
        arguments: AsistenciaEventRouteArgs.attendance(id),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Crea o activa un evento para usar el registro manual con contexto.',
          ),
        ),
      );
      Navigator.pushNamed(context, '/asistencia/crear_attendance_event');
    }
  }

  void _showAsistenciaHelpSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppDesignTokens.background,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ayuda · Asistencia',
                style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppDesignTokens.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Crea un evento de asistencia, registra con QR o lista manual, '
                'revisa el listado general y exporta reportes.',
                style: AppDesignTokens.bodyMuted(sheetCtx),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  _openLegacyEventos(context);
                },
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('Eventos históricos (compatibilidad)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLegacyEventos(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: const Text('Eventos históricos'),
            backgroundColor: AppDesignTokens.primaryDark,
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<List<EventoAsistencia>>(
            stream: _legacyService.getAllEventos(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final eventos = snap.data ?? [];
              if (eventos.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay eventos en el sistema anterior.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: eventos.length,
                itemBuilder: (context, i) {
                  final e = eventos[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(e.nombre),
                      subtitle: Text(_formatFechaHora(e.fecha)),
                      onTap: () => Navigator.pushNamed(
                        ctx,
                        '/asistencia/evento_detail',
                        arguments: e,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? UserRole.user;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      bottomNavigationBar: VotoModuleBottomNavigation(
        role: role,
        selection: VotoNavSlot.asistencia,
      ),
      body: StreamBuilder<List<AttendanceEvent>>(
        stream: _attendanceService.getAllEvents(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Column(
              children: [
                _AsistenciaPremiumHeader(
                  user: auth.user,
                  pendingCount: 0,
                  onBack: () => _onBack(context),
                  onAvatarTap: () => Navigator.pushNamed(context, '/profile'),
                  onNotificationsTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Alertas: usa el listado de eventos para seguimiento.',
                        ),
                      ),
                    );
                  },
                  onSearchTap: () =>
                      Navigator.pushNamed(context, '/asistencia/asistencias'),
                  onHelpTap: () => _showAsistenciaHelpSheet(context),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudo cargar eventos:\n${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          final events = snap.data ?? [];
          final proximos = _proximosEventos(events);
          final pending = _pendingOperationalCount(events);
          final viewportWidth = MediaQuery.sizeOf(context).width;
          final isDesktop = viewportWidth >= 900;
          final centeredGutter = (viewportWidth - 1120) / 2;
          final contentPadding =
              centeredGutter > AppDesignTokens.horizontalPadding
              ? centeredGutter
              : AppDesignTokens.horizontalPadding;
          final useThreeColumns = viewportWidth >= 1050;
          final quickActionColumns = useThreeColumns ? 3 : 2;
          final quickActionRatio = useThreeColumns
              ? 2.15
              : (isDesktop ? 1.8 : 1.32);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _AsistenciaPremiumHeader(
                  user: auth.user,
                  pendingCount: pending,
                  onBack: () => _onBack(context),
                  onAvatarTap: () => Navigator.pushNamed(context, '/profile'),
                  onNotificationsTap: () {
                    if (pending == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No hay eventos operativos pendientes.',
                          ),
                        ),
                      );
                    } else {
                      Navigator.pushNamed(context, '/asistencia/asistencias');
                    }
                  },
                  onSearchTap: () =>
                      Navigator.pushNamed(context, '/asistencia/asistencias'),
                  onHelpTap: () => _showAsistenciaHelpSheet(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding,
                    10,
                    contentPadding,
                    6,
                  ),
                  child: _AsistenciaStatsRow(
                    attendanceService: _attendanceService,
                    events: events,
                    eventosActivos: pending,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding,
                    6,
                    contentPadding,
                    12,
                  ),
                  child: _AsistenciaHeroPanel(
                    onCrearEvento: () => Navigator.pushNamed(
                      context,
                      '/asistencia/crear_attendance_event',
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding,
                    0,
                    contentPadding,
                    8,
                  ),
                  child: Text(
                    'Acciones rápidas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppDesignTokens.primaryDark,
                      fontSize: isDesktop ? 20 : null,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: contentPadding),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: quickActionColumns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: quickActionRatio,
                  ),
                  delegate: SliverChildListDelegate.fixed([
                    _AsistenciaQuickCard(
                      title: 'Crear evento',
                      subtitle: 'Nuevo control',
                      icon: Icons.dashboard_customize_outlined,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/asistencia/crear_attendance_event',
                      ),
                    ),
                    _AsistenciaQuickCard(
                      title: 'Escanear QR',
                      subtitle: 'Registro rápido',
                      icon: Icons.qr_code_scanner_rounded,
                      onTap: () => _openScannerWithHighlight(events),
                    ),
                    _AsistenciaQuickCard(
                      title: 'Manual',
                      subtitle: 'Marcar asistencia',
                      icon: Icons.check_circle_outline_rounded,
                      onTap: () => _openRegistroManualWithHighlight(events),
                    ),
                    _AsistenciaQuickCard(
                      title: 'Asistencias',
                      subtitle: 'Listado general',
                      icon: Icons.format_list_bulleted_rounded,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/asistencia/asistencias',
                      ),
                    ),
                    _AsistenciaQuickCard(
                      title: 'Exportar',
                      subtitle: 'PDF / CSV / Excel',
                      icon: Icons.file_download_outlined,
                      onTap: () =>
                          Navigator.pushNamed(context, '/asistencia/exportar'),
                    ),
                    _AsistenciaQuickCard(
                      title: 'Personas',
                      subtitle: 'Base de socios',
                      icon: Icons.groups_2_outlined,
                      onTap: () =>
                          Navigator.pushNamed(context, '/asistencia/personas'),
                    ),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding,
                    22,
                    contentPadding,
                    8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Próximos eventos',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppDesignTokens.primaryDark,
                              fontSize: isDesktop ? 20 : null,
                            ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/asistencia/asistencias',
                        ),
                        child: const Text(
                          'Ver todos',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (events.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: contentPadding),
                    child: PremiumCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 52,
                            color: AppDesignTokens.primary.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay eventos de asistencia',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignTokens.primaryDark,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Crea un evento para convocar socios y registrar asistencias.',
                            textAlign: TextAlign.center,
                            style: AppDesignTokens.bodyMuted(context),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/asistencia/crear_attendance_event',
                            ),
                            icon: const Icon(Icons.add_chart),
                            label: const Text('Crear evento'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppDesignTokens.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (proximos.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: contentPadding),
                    child: PremiumCard(
                      margin: EdgeInsets.zero,
                      child: Text(
                        'No hay próximos eventos activos. Revisa «Ver todos» o el historial.',
                        style: AppDesignTokens.bodyMuted(context),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding,
                    0,
                    contentPadding,
                    100,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final e = proximos[index];
                      return _ProximoEventoCard(
                        event: e,
                        formatFecha: _formatFechaLarga,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/asistencia/attendance_event_detail',
                          arguments: e.id,
                        ),
                      );
                    }, childCount: proximos.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AsistenciaStatsRow extends StatelessWidget {
  const _AsistenciaStatsRow({
    required this.attendanceService,
    required this.events,
    required this.eventosActivos,
  });

  final AttendanceService attendanceService;
  final List<AttendanceEvent> events;
  final int eventosActivos;

  @override
  Widget build(BuildContext context) {
    final highlight = AttendanceService.pickHighlightedOperationalEventId(
      events,
    );

    if (highlight == null) {
      return Row(
        children: [
          Expanded(
            child: _statCell(
              context,
              label: 'Eventos activos',
              value: '$eventosActivos',
              valueColor: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCell(
              context,
              label: 'Asistencias',
              value: '—',
              valueColor: AppDesignTokens.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCell(
              context,
              label: 'Cumplimiento',
              value: '—',
              valueColor: Colors.blue.shade700,
            ),
          ),
        ],
      );
    }

    return FutureBuilder<AttendanceHubDashboardData?>(
      key: ValueKey(highlight),
      future: attendanceService.buildHubDashboardData(highlight),
      builder: (context, fut) {
        final data = fut.data;
        final pct = data != null && data.totalConvocados > 0
            ? '${data.porcentajePresentes.round()}%'
            : '—';
        final asistencias = data != null ? '${data.presentes}' : '—';

        return Row(
          children: [
            Expanded(
              child: _statCell(
                context,
                label: 'Eventos activos',
                value: '$eventosActivos',
                valueColor: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCell(
                context,
                label: 'Asistencias',
                value:
                    fut.connectionState == ConnectionState.waiting &&
                        !fut.hasData
                    ? '…'
                    : asistencias,
                valueColor: AppDesignTokens.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCell(
                context,
                label: 'Cumplimiento',
                value:
                    fut.connectionState == ConnectionState.waiting &&
                        !fut.hasData
                    ? '…'
                    : pct,
                valueColor: Colors.blue.shade700,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCell(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
  }) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 18 : 14,
        horizontal: 8,
      ),
      borderRadius: AppDesignTokens.radiusMedium,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: isDesktop ? 30 : 26,
              fontWeight: FontWeight.w900,
              color: valueColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 14 : 12,
              fontWeight: FontWeight.w700,
              color: AppDesignTokens.primaryDark.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta principal del mock `13_inicio_asistencia`: CTA hacia creación de evento.
class _AsistenciaHeroPanel extends StatelessWidget {
  const _AsistenciaHeroPanel({required this.onCrearEvento});

  final VoidCallback onCrearEvento;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 18,
        isDesktop ? 24 : 20,
        isDesktop ? 24 : 18,
        isDesktop ? 24 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppDesignTokens.lavanda,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppDesignTokens.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panel de asistencia',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppDesignTokens.primaryDark,
                        fontSize: isDesktop ? 20 : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Registra asistencia por QR o manual, gestiona personas '
                      'y exporta reportes.',
                      style: AppDesignTokens.bodyMuted(context).copyWith(
                        fontSize: isDesktop ? 16 : null,
                        color: AppDesignTokens.primaryDark.withValues(
                          alpha: 0.68,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onCrearEvento,
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignTokens.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Crear evento',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _AsistenciaQuickCard extends StatelessWidget {
  const _AsistenciaQuickCard({
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
        onTap: onTap,
        child: PremiumCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 18 : 14,
            isDesktop ? 18 : 14,
            isDesktop ? 18 : 14,
            isDesktop ? 18 : 16,
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.lavanda,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppDesignTokens.primary.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppDesignTokens.primary,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppDesignTokens.lavanda,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppDesignTokens.primary, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppDesignTokens.primaryDark,
                      fontSize: isDesktop ? 17 : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppDesignTokens.primaryDark.withValues(
                        alpha: 0.68,
                      ),
                      fontSize: isDesktop ? 14 : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProximoEventoCard extends StatelessWidget {
  const _ProximoEventoCard({
    required this.event,
    required this.formatFecha,
    required this.onTap,
  });

  final AttendanceEvent event;
  final String Function(int ms) formatFecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final st = event.estado.toLowerCase().trim();
    final bool esActivo =
        st == 'en_curso' ||
        (event.fecha <= now && event.fechaFinVigenciaMs >= now);

    final Color dotColor = esActivo
        ? Colors.green.shade600
        : Colors.blue.shade600;
    final String badgeLabel = esActivo ? 'Activo' : 'Programado';
    final Color badgeFg = esActivo
        ? Colors.green.shade900
        : Colors.blue.shade900;
    final Color badgeBg = esActivo
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFE3F2FD);

    final lugar = event.lugar.trim().isEmpty ? 'Sin lugar' : event.lugar.trim();

    return PremiumCard(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.lavanda,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppDesignTokens.primaryDark,
                              height: 1.2,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatFecha(event.fecha)} · $lugar',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppDesignTokens.primaryDark.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: badgeFg,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: badgeFg.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AsistenciaPremiumHeader extends StatelessWidget {
  const _AsistenciaPremiumHeader({
    required this.user,
    required this.pendingCount,
    required this.onBack,
    required this.onAvatarTap,
    required this.onNotificationsTap,
    required this.onSearchTap,
    required this.onHelpTap,
  });

  final AppUser? user;
  final int pendingCount;
  final VoidCallback onBack;
  final VoidCallback onAvatarTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSearchTap;
  final VoidCallback onHelpTap;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return ClipPath(
      clipper: _AsistenciaWaveClipper(),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 170),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppDesignTokens.primaryDark, AppDesignTokens.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 8,
              isDesktop ? 14 : 8,
              isDesktop ? 24 : 10,
              58,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VotoCircleIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: onBack,
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.black26,
                      shape: CircleBorder(
                        side: BorderSide(
                          color: AppDesignTokens.primary.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onAvatarTap,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: DashboardWelcomeAvatar(user: user, size: 40),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Sistema de Asistencia',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: isDesktop ? 28 : null,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Control de asistencia a eventos',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: isDesktop ? 16 : null,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _HeaderCircleIcon(
                      icon: Icons.notifications_none_rounded,
                      badgeCount: pendingCount,
                      onTap: onNotificationsTap,
                    ),
                    const SizedBox(width: 6),
                    _HeaderCircleIcon(
                      icon: Icons.search_rounded,
                      badgeCount: 0,
                      onTap: onSearchTap,
                    ),
                    const SizedBox(width: 6),
                    _HeaderCircleIcon(
                      icon: Icons.help_outline_rounded,
                      badgeCount: 0,
                      onTap: onHelpTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCircleIcon extends StatelessWidget {
  const _HeaderCircleIcon({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: CircleBorder(
        side: BorderSide(
          color: AppDesignTokens.primary.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: AppDesignTokens.primary, size: 22),
            ),
            if (badgeCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AsistenciaWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 42)
      ..cubicTo(
        size.width * 0.22,
        size.height - 12,
        size.width * 0.64,
        size.height - 88,
        size.width,
        size.height - 36,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
