import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/models/member.dart';
import '../../core/models/user_role.dart';
import '../../core/utils/qr_encoding_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/asistencia_service.dart';
import '../../services/attendance_service.dart';
import '../../services/members_service.dart';
import '../elections/widgets/voto_premium_chrome.dart';

/// Detalle premium de socio con historial de asistencia (`13_asistencia_detalle_persona`).
class AsistenciaPersonDetailScreen extends StatefulWidget {
  const AsistenciaPersonDetailScreen({super.key, required this.memberId});

  final String memberId;

  @override
  State<AsistenciaPersonDetailScreen> createState() =>
      _AsistenciaPersonDetailScreenState();
}

class _AsistenciaPersonDetailScreenState
    extends State<AsistenciaPersonDetailScreen> {
  final MembersService _membersService = MembersService();
  final AttendanceService _attendanceService = AttendanceService();
  final AsistenciaService _legacyAsistencia = AsistenciaService();

  static final _fechaCorta = DateFormat('dd/MM/yyyy');

  Member? _member;
  bool _loadingMember = true;
  String? _memberError;

  StreamSubscription<MemberAttendanceSummary>? _summarySub;
  MemberAttendanceSummary? _summary;
  Object? _summaryError;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _summarySub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _reloadMember(resetSummary: false);
    if (!mounted || _member == null) return;
    _listenSummary();
  }

  Future<void> _reloadMember({required bool resetSummary}) async {
    setState(() {
      _loadingMember = true;
      _memberError = null;
    });
    try {
      final m = await _membersService.getMemberById(widget.memberId);
      if (!mounted) return;
      if (m == null) {
        setState(() {
          _member = null;
          _memberError =
              'No se encontró el socio (${widget.memberId}) o no tienes permiso.';
          _loadingMember = false;
          _summary = null;
        });
        return;
      }
      setState(() {
        _member = m;
        _loadingMember = false;
      });
      if (resetSummary) {
        await _restartSummarySubscription();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memberError = e.toString();
        _loadingMember = false;
      });
    }
  }

  Future<void> _restartSummarySubscription() async {
    await _summarySub?.cancel();
    _summarySub = null;
    if (!mounted) return;
    setState(() {
      _summary = null;
      _summaryError = null;
    });
    _listenSummary();
  }

  void _listenSummary() {
    final id = widget.memberId.trim();
    if (id.isEmpty) return;
    _summarySub?.cancel();
    _summarySub = _attendanceService
        .watchMemberAttendanceSummary(id)
        .listen(
          (sum) {
            if (!mounted) return;
            setState(() {
              _summary = sum;
              _summaryError = null;
            });
          },
          onError: (Object e, StackTrace st) {
            debugPrint('Resumen persona: $e\n$st');
            if (!mounted) return;
            setState(() => _summaryError = e);
          },
        );
  }

  void _sheetMetodologia() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cómo se calculan las métricas',
                    style: AppDesignTokens.titleLarge(ctx),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '«Presentes» cuenta marcas con estado efectivo Presente '
                    'en eventos donde el socio aparece convocado (excluye '
                    '«No convocado» por lista o modalidad).\n\n'
                    '«Faltas» agrupa ausencias sin justificación sobre esos '
                    'convocados.\n'
                    '«Cumplimiento» es Presentes sobre convocados.\n\n'
                    'El historial muestra todas las líneas derivadas '
                    '(incluye no convocados) ordenadas desde el evento más '
                    'reciente.',
                    style: AppDesignTokens.bodyMuted(ctx),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirQrSheet(Member member) {
    final qrData = member.workerCode?.trim().isNotEmpty == true
        ? QREncodingHelper.generateMemberQRCode(member)
        : member.id;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                member.fullName,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppDesignTokens.primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppDesignTokens.primary.withValues(alpha: 0.12),
                      ),
                      boxShadow: AppDesignTokens.cardShadow,
                    ),
                    child: QrImageView(
                      data: qrData,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'N° Socio: ${member.memberNumber}',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              if (member.workerCode?.trim().isNotEmpty == true)
                Text('TRAB-${member.workerCode}'),
              if (member.documentId?.trim().isNotEmpty == true)
                Text('Cédula: ${member.documentId}'),
              if (member.workerCode == null ||
                  member.workerCode!.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Sin workerCode: el QR usa el ID interno del socio.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onHistorialTap(AsistenciaDetalle d) async {
    try {
      if (d.isLegacy) {
        final ev = await _legacyAsistencia.getEventoById(d.eventId);
        if (!mounted) return;
        if (ev == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontró el evento (histórico).'),
            ),
          );
          return;
        }
        await Navigator.pushNamed(
          context,
          '/asistencia/evento_detail',
          arguments: ev,
        );
      } else {
        await Navigator.pushNamed(
          context,
          '/asistencia/attendance_event_detail',
          arguments: d.eventId,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo abrir el evento: $e')));
    }
  }

  ({Color accent, Color pill, String etiquetaLista}) _estiloHistorial(
    String estado,
  ) {
    final lower = estado.trim().toLowerCase();
    if (lower.contains('presente')) {
      return (
        accent: Colors.green.shade600,
        pill: Colors.green.shade600,
        etiquetaLista: 'Presente',
      );
    }
    if (lower.contains('justificado')) {
      return (
        accent: const Color(0xFFE67E22),
        pill: const Color(0xFFE67E22),
        etiquetaLista: 'Ausente justificado',
      );
    }
    if (lower.contains('no convocado')) {
      return (
        accent: Colors.blueGrey.shade500,
        pill: Colors.blueGrey.shade400,
        etiquetaLista: 'No convocado',
      );
    }
    return (
      accent: const Color(0xFFE74C3C),
      pill: const Color(0xFFE74C3C),
      etiquetaLista: 'Ausente',
    );
  }

  Widget _kpiRow(MemberAttendanceSummary s) {
    final conv = s.totalConvocados;
    final pct = conv > 0
        ? ((100 * s.totalAsistencias / conv)).round().clamp(0, 100)
        : 0;

    return Row(
      children: [
        Expanded(
          child: _MiniKpi(
            value: '${s.totalAsistencias}',
            label: 'Presentes',
            valueColor: const Color(0xFF2ECC71),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniKpi(
            value: '${s.totalFaltas}',
            label: 'Faltas',
            valueColor: const Color(0xFFE74C3C),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniKpi(
            value: conv > 0 ? '$pct%' : '—',
            label: 'Cumplimiento',
            valueColor: const Color(0xFF3498DB),
          ),
        ),
      ],
    );
  }

  Widget _profileCard(BuildContext context, Member m) {
    final active = m.status == MemberStatus.active;
    final socio = m.memberNumber.trim().isEmpty ? 'Sin N°' : m.memberNumber;
    final trab = m.workerCode?.trim().isNotEmpty == true
        ? m.workerCode!.trim()
        : null;
    final idLine = trab != null ? 'S-$socio · TRAB-$trab' : 'S-$socio';

    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppDesignTokens.lavanda,
            child: Icon(
              Icons.person_rounded,
              size: 40,
              color: AppDesignTokens.primaryDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.fullName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppDesignTokens.primaryDark,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                    ),
                  ),
                  child: Text(
                    active ? 'Socio activo' : 'Socio inactivo',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: active
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  idLine,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historialTile(BuildContext context, AsistenciaDetalle d) {
    final est = _estiloHistorial(d.estado);
    final fechaTxt = _fechaCorta.format(
      DateTime.fromMillisecondsSinceEpoch(d.fecha),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
        onTap: () => unawaited(_onHistorialTap(d)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            border: Border.all(
              color: AppDesignTokens.primary.withValues(alpha: 0.06),
            ),
            boxShadow: AppDesignTokens.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: est.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(top: BorderSide(color: est.accent, width: 4)),
                ),
                child: Icon(
                  Icons.event_note_rounded,
                  color: est.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.eventName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppDesignTokens.primaryDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$fechaTxt · ${est.etiquetaLista}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 22,
                    decoration: BoxDecoration(
                      color: est.pill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
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
      backgroundColor: Colors.white,
      bottomNavigationBar: VotoModuleBottomNavigation(
        role: role,
        selection: VotoNavSlot.asistencia,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Detalle de persona',
            subtitle: 'Historial de asistencia',
            onBack: () => Navigator.maybePop(context),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VotoCircleIconButton(
                  icon: Icons.info_outline_rounded,
                  onTap: _sheetMetodologia,
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: () => unawaited(_reloadMember(resetSummary: true)),
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: () {
                    final memb = _member;
                    if (memb != null) unawaited(_abrirQrSheet(memb));
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loadingMember
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppDesignTokens.primary,
                    ),
                  )
                : _memberError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_memberError!, textAlign: TextAlign.center),
                    ),
                  )
                : _member == null
                ? const Center(child: Text('Sin datos'))
                : _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final m = _member!;
    final s = _summary;
    final err = _summaryError;

    final listaResumen = s?.detalles ?? const <AsistenciaDetalle>[];

    final bottomQr = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.horizontalPadding,
        16,
        AppDesignTokens.horizontalPadding,
        8,
      ),
      child: PrimaryButton(
        label: 'Ver código QR',
        icon: Icons.qr_code_rounded,
        onPressed: () => unawaited(_abrirQrSheet(m)),
      ),
    );

    if (err != null) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDesignTokens.horizontalPadding,
              8,
              AppDesignTokens.horizontalPadding,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Transform.translate(
                  offset: const Offset(0, -12),
                  child: _profileCard(context, m),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No se pudo cargar el historial: $err',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          bottomQr,
        ],
      );
    }

    if (s == null) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDesignTokens.horizontalPadding,
              8,
              AppDesignTokens.horizontalPadding,
              8,
            ),
            child: Transform.translate(
              offset: const Offset(0, -12),
              child: _profileCard(context, m),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          bottomQr,
        ],
      );
    }

    final sum = s;
    final list = sum.detalles;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppDesignTokens.horizontalPadding,
            0,
            AppDesignTokens.horizontalPadding,
            14,
          ),
          sliver: SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _profileCard(context, m),
                  const SizedBox(height: 14),
                  _kpiRow(sum),
                  const SizedBox(height: 14),
                  Text(
                    'Historial reciente',
                    style: AppDesignTokens.titleLarge(context),
                  ),
                  const SizedBox(height: 10),
                  if (listaResumen.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'Sin eventos en el resumen consolidado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (list.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppDesignTokens.horizontalPadding,
              0,
              AppDesignTokens.horizontalPadding,
              16,
            ),
            sliver: SliverList.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _historialTile(ctx, list[i]),
            ),
          ),
        SliverToBoxAdapter(child: bottomQr),
      ],
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      borderRadius: AppDesignTokens.radiusMedium,
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
