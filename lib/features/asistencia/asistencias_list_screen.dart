import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/asistencia_service.dart';
import '../../services/attendance_service.dart';
import '../elections/widgets/voto_premium_chrome.dart';
import 'widgets/attendance_operational_dashboard.dart';

/// Listado premium de eventos de asistencia (`02_asistencia_eventos`).
/// Estado vacío alineado con `15_asistencia_sin_eventos` (sin KPI/búsqueda).
/// Mantiene histórico global y panel operativo vía cabecera.
class AsistenciasListScreen extends StatefulWidget {
  const AsistenciasListScreen({super.key});

  @override
  State<AsistenciasListScreen> createState() => _AsistenciasListScreenState();
}

class _AsistenciasListScreenState extends State<AsistenciasListScreen> {
  final AsistenciaService _legacyService = AsistenciaService();
  final AttendanceService _attendanceService = AttendanceService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  static const List<String> _mesesCortos = [
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

  static int _countHoy(List<AttendanceEvent> events) {
    final now = DateTime.now();
    final startToday = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final endToday = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;
    return events
        .where((e) => e.fecha <= endToday && e.fechaFinVigenciaMs >= startToday)
        .length;
  }

  static int _countActivos(List<AttendanceEvent> events) {
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

  static int _countFinalizados(List<AttendanceEvent> events) {
    return events
        .where((e) => e.estado.toLowerCase().trim() == 'finalizado')
        .length;
  }

  static List<AttendanceEvent> _filterEvents(
    List<AttendanceEvent> events,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return events;
    return events
        .where(
          (e) =>
              e.nombre.toLowerCase().contains(q) ||
              e.lugar.toLowerCase().contains(q) ||
              e.descripcion.toLowerCase().contains(q),
        )
        .toList();
  }

  static _EventVisual _visualFor(AttendanceEvent e) {
    final st = e.estado.toLowerCase().trim();
    if (!e.activo) {
      return (
        badge: 'Borrador',
        badgeBg: const Color(0xFFFFF8E1),
        badgeFg: const Color(0xFFE65100),
        iconBg: const Color(0xFFFFF8E1),
        iconFg: const Color(0xFFE65100),
      );
    }
    if (st == 'finalizado') {
      return (
        badge: 'Finalizado',
        badgeBg: const Color(0xFFF5F5F5),
        badgeFg: const Color(0xFF424242),
        iconBg: const Color(0xFFECEFF1),
        iconFg: const Color(0xFF546E7A),
      );
    }
    if (st == 'en_curso') {
      return (
        badge: 'En curso',
        badgeBg: const Color(0xFFE8F5E9),
        badgeFg: const Color(0xFF2E7D32),
        iconBg: const Color(0xFFE8F5E9),
        iconFg: const Color(0xFF2E7D32),
      );
    }
    return (
      badge: 'Programado',
      badgeBg: const Color(0xFFE3F2FD),
      badgeFg: const Color(0xFF1565C0),
      iconBg: const Color(0xFFE3F2FD),
      iconFg: const Color(0xFF1565C0),
    );
  }

  static String _metaLine(AttendanceEvent e, _EventVisual v) {
    if (v.badge == 'Finalizado') {
      final lugar = e.lugar.trim().isEmpty ? '' : ' · ${e.lugar.trim()}';
      return 'Finalizado$lugar';
    }
    final d = DateTime.fromMillisecondsSinceEpoch(e.fecha);
    final mes = _mesesCortos[d.month - 1];
    final hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final lugar = e.lugar.trim().isEmpty ? 'Sin lugar' : e.lugar.trim();
    return '${d.day} $mes · $hm · $lugar';
  }

  static String _formatFechaRegistro(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _openOperationalDashboardSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppDesignTokens.background,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: AttendanceOperationalDashboard(
            service: _attendanceService,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  void _sheetEmptyListaInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sin eventos todavía',
                  style: AppDesignTokens.titleLarge(ctx),
                ),
                const SizedBox(height: 10),
                Text(
                  'Una vez creado un evento de asistencia podrás buscar por '
                  'nombre o lugar en el encabezado del listado, abrir métricas '
                  'rápidas y revisar registros desde aquí mismo.',
                  style: AppDesignTokens.bodyMuted(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openHistoricoRegistros(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppDesignTokens.background,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Registros globales (histórico)',
                style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppDesignTokens.primaryDark,
                ),
              ),
            ),
            SizedBox(
              height: MediaQuery.sizeOf(sheetCtx).height * 0.62,
              child: StreamBuilder<List<AsistenciaConDatos>>(
                stream: _legacyService.watchAllAsistenciasConDatos(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No hay registros en la lista global.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final a = list[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(a.persona.nombreCompleto),
                          subtitle: Text(
                            '${a.evento.nombre} • '
                            '${a.asistencia.asistio ? "Asistió" : "No asistió"} • '
                            '${_formatFechaRegistro(a.asistencia.fechaRegistro ?? 0)}',
                            maxLines: 2,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
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
          final cargandoPrimero =
              snap.connectionState == ConnectionState.waiting && !snap.hasData;

          final events = snap.data ?? [];
          final sinEventosFirebase =
              snap.hasData && !snap.hasError && events.isEmpty;
          final subtitulo = sinEventosFirebase
              ? 'Sin registros'
              : 'Listado y seguimiento';

          Widget cuerpo;
          if (snap.hasError) {
            cuerpo = Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar eventos:\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          } else if (cargandoPrimero) {
            cuerpo = Center(
              child: CircularProgressIndicator(color: AppDesignTokens.primary),
            );
          } else if (sinEventosFirebase) {
            cuerpo = _listaVaciaPremium(context);
          } else {
            final filtered = _filterEvents(events, _searchController.text);
            final hoy = _countHoy(events);
            final activos = _countActivos(events);
            final finalizados = _countFinalizados(events);

            cuerpo = CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDesignTokens.horizontalPadding,
                      10,
                      AppDesignTokens.horizontalPadding,
                      8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _EventosStatCell(
                            label: 'Hoy',
                            value: '$hoy',
                            valueColor: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _EventosStatCell(
                            label: 'Activos',
                            value: '$activos',
                            valueColor: AppDesignTokens.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _EventosStatCell(
                            label: 'Finalizados',
                            value: '$finalizados',
                            valueColor: const Color(0xFF546E7A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDesignTokens.horizontalPadding,
                      4,
                      AppDesignTokens.horizontalPadding,
                      10,
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar o filtrar registros…',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppDesignTokens.primaryDark.withValues(
                            alpha: 0.45,
                          ),
                        ),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppDesignTokens.primary.withValues(
                              alpha: 0.14,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppDesignTokens.primary.withValues(
                              alpha: 0.14,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppDesignTokens.primary,
                            width: 1.6,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDesignTokens.horizontalPadding,
                      0,
                      AppDesignTokens.horizontalPadding,
                      14,
                    ),
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/asistencia/crear_attendance_event',
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('+ Crear nuevo evento'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppDesignTokens.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDesignTokens.horizontalPadding,
                      0,
                      AppDesignTokens.horizontalPadding,
                      8,
                    ),
                    child: Text(
                      'Listado',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppDesignTokens.primaryDark,
                      ),
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'Ningún evento coincide con la búsqueda.',
                        style: AppDesignTokens.bodyMuted(context),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDesignTokens.horizontalPadding,
                      0,
                      AppDesignTokens.horizontalPadding,
                      100,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final e = filtered[index];
                        final v = _visualFor(e);
                        return _EventoListCard(
                          event: e,
                          visual: v,
                          metaLine: _metaLine(e, v),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/asistencia/attendance_event_detail',
                            arguments: e.id,
                          ),
                        );
                      }, childCount: filtered.length),
                    ),
                  ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VotoWaveHeader(
                title: 'Eventos de asistencia',
                subtitle: subtitulo,
                onBack: () => Navigator.pop(context),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: sinEventosFirebase
                      ? [
                          VotoCircleIconButton(
                            icon: Icons.insights_outlined,
                            onTap: () =>
                                _openOperationalDashboardSheet(context),
                          ),
                          const SizedBox(width: 6),
                          VotoCircleIconButton(
                            icon: Icons.fact_check_outlined,
                            onTap: () => _openHistoricoRegistros(context),
                          ),
                          const SizedBox(width: 6),
                          VotoCircleIconButton(
                            icon: Icons.info_outline_rounded,
                            onTap: () => _sheetEmptyListaInfo(context),
                          ),
                        ]
                      : [
                          VotoCircleIconButton(
                            icon: Icons.insights_outlined,
                            onTap: () =>
                                _openOperationalDashboardSheet(context),
                          ),
                          const SizedBox(width: 6),
                          VotoCircleIconButton(
                            icon: Icons.fact_check_outlined,
                            onTap: () => _openHistoricoRegistros(context),
                          ),
                          const SizedBox(width: 6),
                          VotoCircleIconButton(
                            icon: Icons.search_rounded,
                            onTap: () => _searchFocus.requestFocus(),
                          ),
                        ],
                ),
              ),
              Expanded(child: cuerpo),
            ],
          );
        },
      ),
    );
  }

  Widget _listaVaciaPremium(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppDesignTokens.horizontalPadding,
          28,
          AppDesignTokens.horizontalPadding,
          32,
        ),
        child: PremiumCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppDesignTokens.lavanda,
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 44,
                    color: AppDesignTokens.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Aún no hay eventos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppDesignTokens.primaryDark,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Crea el primer evento para comenzar a registrar '
                'asistencias.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppDesignTokens.primaryDark.withValues(alpha: 0.62),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Crear evento',
                icon: Icons.add_rounded,
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/asistencia/crear_attendance_event',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _EventVisual = ({
  String badge,
  Color badgeBg,
  Color badgeFg,
  Color iconBg,
  Color iconFg,
});

class _EventosStatCell extends StatelessWidget {
  const _EventosStatCell({
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      borderRadius: AppDesignTokens.radiusMedium,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppDesignTokens.primaryDark.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventoListCard extends StatelessWidget {
  const _EventoListCard({
    required this.event,
    required this.visual,
    required this.metaLine,
    required this.onTap,
  });

  final AttendanceEvent event;
  final _EventVisual visual;
  final String metaLine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
              border: Border.all(
                color: AppDesignTokens.primaryDark.withValues(alpha: 0.08),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: visual.iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_view_week_rounded,
                    color: visual.iconFg,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
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
                        metaLine,
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
                    color: visual.badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    visual.badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: visual.badgeFg,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppDesignTokens.primaryDark.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
