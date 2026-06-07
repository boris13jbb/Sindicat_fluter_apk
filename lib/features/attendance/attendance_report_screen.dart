import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/models/member.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_branding_service.dart';
import '../../services/asistencia_service.dart';
import '../../services/attendance_service.dart';
import '../elections/widgets/voto_premium_chrome.dart';

/// Pantalla de reporte de asistencia (mock `11_asistencia_reporte`).
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final AttendanceService _attendanceSvc = AttendanceService();

  bool _isLoading = true;
  AttendanceReport? _report;
  String? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final report = await _attendanceSvc.generateAttendanceReport(
        widget.eventId,
      );
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  static String _horaMin(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  static int? _firstRegistroMs(AttendanceReport r) {
    final ts = [
      for (final a in r.attendances)
        if (a.fechaRegistro != null && a.fechaRegistro! > 0) a.fechaRegistro!,
    ];
    ts.sort();
    return ts.isEmpty ? null : ts.first;
  }

  static int? _lastRegistroMs(AttendanceReport r) {
    final ts = [
      for (final a in r.attendances)
        if (a.fechaRegistro != null && a.fechaRegistro! > 0) a.fechaRegistro!,
    ];
    ts.sort();
    return ts.isEmpty ? null : ts.last;
  }

  static int _duplicateExtraDocs(AttendanceReport r) {
    final counts = <String, int>{};
    for (final a in r.attendances) {
      final id = a.personaId.trim();
      if (id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    var extra = 0;
    counts.forEach((_, c) {
      if (c > 1) extra += c - 1;
    });
    return extra;
  }

  /// Filas compatibles con [AttendanceReportGenerator] (solo lecturas reales).
  List<AsistenciaConDatos> _buildExportRows(AttendanceReport r) {
    if (r.attendances.isEmpty) return [];
    final evUi = EventoAsistencia(
      id: r.event.id,
      nombre: r.event.nombre,
      fecha: r.event.fecha,
      fechaFin: r.event.fechaFin,
      activo: r.event.activo,
      tipoReunion: TipoReunion.fromString(r.event.tipo),
      descripcion: r.event.descripcion.isNotEmpty ? r.event.descripcion : null,
    );
    final mmap = <String, Member>{
      for (final m in [
        ...r.presentMembers,
        ...r.absentMembers,
        ...r.notConvokedMembers,
      ])
        m.id: m,
    };
    return r.attendances.map((a) {
      final mb = mmap[a.personaId];
      final persona = mb != null
          ? PersonaAsistencia(
              id: mb.id,
              nombres: mb.firstName,
              apellidos: mb.lastName,
              identificador: mb.workerCode?.trim().isNotEmpty == true
                  ? mb.workerCode
                  : (mb.memberNumber.trim().isNotEmpty
                        ? mb.memberNumber
                        : mb.documentId),
            )
          : PersonaAsistencia(
              id: a.personaId,
              nombres: '',
              apellidos: '(Sin ficha)',
              identificador: null,
            );
      return AsistenciaConDatos(asistencia: a, persona: persona, evento: evUi);
    }).toList();
  }

  Future<void> _exportarPdf(BuildContext context) async {
    final report = _report;
    if (report == null) return;
    final rows = _buildExportRows(report);
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay documentos en la subcolección de asistencias para '
            'exportar. Las cifras de presentes pueden venir sólo del cruce '
            'con el padrón.',
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );

    setState(() => _exporting = true);
    try {
      final branding = await AppBrandingService().getReportBrandingOnce();
      final logoBytes = await AppBrandingService.loadReportLogoBytes(
        branding?.reportLogoUrl,
      );
      final bytes = await AsistenciaService.generatePDFExportStatic(
        rows,
        reportLogoBytes: logoBytes,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'reporte_asistencia_${widget.eventId}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF listo para compartir o guardar'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _infoIndicador(String titulo, String detalle) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppDesignTokens.titleLarge(ctx)),
                const SizedBox(height: 12),
                Text(detalle, style: AppDesignTokens.bodyMuted(ctx)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _indicatorRow({
    required Color accent,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: Colors.white,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF2B2265),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 22,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _horizontalBar({
    required String label,
    required double percentZeroTo100,
    required Color color,
  }) {
    final v = percentZeroTo100.clamp(0, 100) / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
            Text(
              '${percentZeroTo100.round()}%',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: v > 0 ? v : null,
            minHeight: 10,
            backgroundColor: const Color(0xFFEEEEF2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? UserRole.user;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: VotoModuleBottomNavigation(
        role: role,
        selection: VotoNavSlot.asistencia,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Reporte de asistencia',
            subtitle: 'Resumen del evento',
            onBack: () => Navigator.pop(context),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VotoCircleIconButton(
                  icon: Icons.format_list_bulleted_rounded,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/asistencia/evento_registros',
                    arguments: widget.eventId,
                  ),
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: _loadReport,
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppDesignTokens.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[700]),
              const SizedBox(height: 16),
              Text(
                'Error al cargar reporte',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final report = _report;
    if (report == null) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final rate = report.attendanceRate.clamp(0, 100).toDouble();
    final absentPct = report.totalConvoked > 0
        ? report.absenceRate.clamp(0, 100).toDouble()
        : (report.totalPresent == 0 ? 100.0 : 0.0);
    final firstMs = _firstRegistroMs(report);
    final lastMs = _lastRegistroMs(report);
    final dup = _duplicateExtraDocs(report);
    final green = const Color(0xFF2ECC71);
    final red = const Color(0xFFE74C3C);
    final blue = const Color(0xFF3498DB);
    final orange = const Color(0xFFE67E22);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppDesignTokens.horizontalPadding,
        8,
        AppDesignTokens.horizontalPadding,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Transform.translate(
            offset: const Offset(0, -12),
            child: Row(
              children: [
                Expanded(
                  child: PremiumCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${report.totalPresent}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: green,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Presentes',
                          style: AppDesignTokens.bodyMuted(context),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PremiumCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${report.totalAbsent}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: red,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ausentes',
                          style: AppDesignTokens.bodyMuted(context),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PremiumCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Column(
                      children: [
                        Text(
                          report.totalConvoked > 0 ? '${rate.round()}%' : '—',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: blue,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cumplimiento',
                          style: AppDesignTokens.bodyMuted(context),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          PremiumCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distribución de asistencia',
                  style: AppDesignTokens.titleLarge(context),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(120, 120),
                            painter: _DonutAttendancePainter(
                              progress: rate / 100,
                              activeColor: green,
                              trackColor: const Color(0xFFE8E8ED),
                              strokeWidth: 14,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                report.totalConvoked > 0
                                    ? '${rate.round()}%'
                                    : '0%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  color: green,
                                ),
                              ),
                              Text(
                                'avance',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _horizontalBar(
                            label: 'Presentes',
                            percentZeroTo100: rate,
                            color: green,
                          ),
                          const SizedBox(height: 16),
                          _horizontalBar(
                            label: 'Ausentes',
                            percentZeroTo100: absentPct,
                            color: red,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Indicadores', style: AppDesignTokens.titleLarge(context)),
          const SizedBox(height: 10),
          PremiumCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _indicatorRow(
                  accent: AppDesignTokens.primary,
                  title: 'Primera lectura',
                  subtitle: firstMs != null ? _horaMin(firstMs) : '—',
                  onTap: () => _infoIndicador(
                    'Primera lectura',
                    'Hora local del primer registro con marca de tiempo en la '
                        'subcolección de asistencias de este evento.',
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _indicatorRow(
                  accent: blue,
                  title: 'Última lectura',
                  subtitle: lastMs != null ? _horaMin(lastMs) : '—',
                  onTap: () => _infoIndicador(
                    'Última lectura',
                    'Último registro horario conocido entre los mismos datos.',
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _indicatorRow(
                  accent: orange,
                  title: 'Duplicados bloqueados',
                  subtitle: '$dup',
                  onTap: () => _infoIndicador(
                    'Duplicados bloqueados',
                    'Suma de documentos extra en Firestore después del primero '
                        'para el mismo personaId (posibles relecturas registradas '
                        'como nuevas filas).',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Exportar reporte',
            icon: Icons.picture_as_pdf_rounded,
            isLoading: _exporting,
            onPressed: (_exporting || _isLoading)
                ? null
                : () => _exportarPdf(context),
          ),
        ],
      ),
    );
  }
}

class _DonutAttendancePainter extends CustomPainter {
  _DonutAttendancePainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color activeColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = (progress.clamp(0.0, 1.0)) * 2 * pi;

    canvas.drawArc(rect, -pi / 2, 2 * pi, false, trackPaint);

    if (sweep > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, sweep, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutAttendancePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
