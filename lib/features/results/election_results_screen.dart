import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/election.dart';
import '../../core/models/candidate.dart';
import '../../core/models/user_role.dart';
import '../../core/security/election_visibility.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../providers/auth_provider.dart';
import '../../services/election_service.dart';
import '../../services/members_service.dart';
import '../../services/app_branding_service.dart';
import '../../core/reports/election_report_generator.dart';
import '../elections/widgets/voto_premium_chrome.dart';

class ElectionResultsScreen extends StatefulWidget {
  const ElectionResultsScreen({super.key, required this.electionId});

  final String electionId;

  @override
  State<ElectionResultsScreen> createState() => _ElectionResultsScreenState();
}

class _ElectionResultsScreenState extends State<ElectionResultsScreen> {
  late ElectionService _electionService;
  late Future<ResultsBootstrap> _bootstrap;
  final MembersService _membersService = MembersService();
  late final Future<int> _activeMembersCountFuture;

  static const Duration _bootstrapTimeout = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _electionService = ElectionService();
    _bootstrap = _loadBootstrap();
    _activeMembersCountFuture = _loadActiveMemberCount();
  }

  Future<int> _loadActiveMemberCount() async {
    try {
      final list = await _membersService.getActiveMembers().first;
      return list.isEmpty ? 1 : list.length;
    } catch (_) {
      return 1;
    }
  }

  Future<ResultsBootstrap> _loadBootstrap() {
    return _electionService
        .loadResultsBootstrap(widget.electionId)
        .timeout(
          _bootstrapTimeout,
          onTimeout: () => throw TimeoutException(
            'La conexión es demasiado lenta. Comprueba datos móviles o Wi‑Fi.',
          ),
        );
  }

  void _retryLoad() {
    setState(() {
      _electionService = ElectionService();
      _bootstrap = _loadBootstrap();
    });
  }

  void _showExportReportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: const Text('Exportar PDF'),
                subtitle: const Text(
                  'Se abrirá el menú del sistema para guardar o compartir',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleExport(context, 'pdf');
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_rounded),
                title: const Text('Exportar CSV'),
                subtitle: const Text(
                  'Se abrirá el menú del sistema para guardar o compartir',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleExport(context, 'csv');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRole = context.watch<AuthProvider>().user?.role;
    final isAdmin =
        userRole == UserRole.admin || userRole == UserRole.superadmin;
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: FutureBuilder<ResultsBootstrap>(
        future: _bootstrap,
        builder: (context, bootSnap) {
          final subtitle = bootSnap.connectionState == ConnectionState.waiting &&
                  !bootSnap.hasData
              ? 'Cargando…'
              : (bootSnap.hasData &&
                      (bootSnap.data!.election?.title.trim().isNotEmpty == true))
                  ? bootSnap.data!.election!.title.trim()
                  : 'Resultados electorales';

          Widget inner() {
          if (bootSnap.hasError) {
            return _LoadError(
              message: '${bootSnap.error}',
              onRetry: _retryLoad,
            );
          }
          if (bootSnap.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Cargando resultados...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Obteniendo datos de la elección',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          final boot = bootSnap.data!;
          if (boot.election == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDesignTokens.horizontalPadding),
                child: PremiumCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 56,
                        color: AppDesignTokens.primary.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Elección no encontrada',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppDesignTokens.primaryDark,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'La elección no existe o fue eliminada.\nVerifica el enlace o vuelve al listado.',
                        style: AppDesignTokens.bodyMuted(context),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return StreamBuilder<ElectionLiveState>(
            stream: _electionService.watchElectionLive(widget.electionId),
            initialData: ElectionLiveState(
              election: boot.election,
              isSyncing: true,
            ),
            builder: (context, electionSnap) {
              if (electionSnap.hasError) {
                return _LoadError(
                  message: '${electionSnap.error}',
                  onRetry: _retryLoad,
                );
              }
              final liveElection = electionSnap.data!;
              final election = liveElection.election;
              if (election == null) {
                return const Center(child: Text('Elección no encontrada'));
              }
              if (!canViewElectionResults(
                election: election,
                viewerRole: userRole,
              )) {
                return _ResultsLockedCard(election: election);
              }

              return StreamBuilder<CandidatesLiveState>(
                stream: _electionService.watchCandidatesLive(widget.electionId),
                initialData: CandidatesLiveState(
                  candidates: boot.candidates,
                  isSyncing: true,
                ),
                builder: (context, candidatesSnap) {
                  if (candidatesSnap.hasError) {
                    return _LoadError(
                      message: '${candidatesSnap.error}',
                      onRetry: _retryLoad,
                    );
                  }

                  final candidatesState = candidatesSnap.data!;
                  final candidates = candidatesState.candidates;
                  final syncing =
                      liveElection.isSyncing || candidatesState.isSyncing;

                  final sortedCandidates = List<Candidate>.from(candidates)
                    ..sort((a, b) => b.voteCount.compareTo(a.voteCount));

                  final totalVotes = sortedCandidates.fold<int>(
                    0,
                    (sum, c) => sum + c.voteCount,
                  );

                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            AppDesignTokens.horizontalPadding,
                            12,
                            AppDesignTokens.horizontalPadding,
                            16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (syncing) const _SyncRibbon(),
                              if (syncing) const SizedBox(height: 12),
                              FutureBuilder<int>(
                                future: _activeMembersCountFuture,
                                builder: (context, membersSnap) {
                                  final members = math.max(
                                    1,
                                    membersSnap.data ?? 1,
                                  );
                                  final participationPct = totalVotes == 0
                                      ? 0
                                      : math.min(
                                          100,
                                          (100 * totalVotes / members).round(),
                                        );
                                  return _ResultsKpiRow(
                                    totalVotes: totalVotes,
                                    participationPct: participationPct,
                                    candidatesCount: sortedCandidates.length,
                                  );
                                },
                              ),
                              const SizedBox(height: 18),
                              if (sortedCandidates.isEmpty)
                                const _EmptyResultsCard()
                              else
                                _LiveResultsSection(
                                  candidates: sortedCandidates,
                                  totalVotes: totalVotes,
                                ),
                              const SizedBox(height: 14),
                              const _ObservacionesCard(),
                            ],
                          ),
                        ),
                      ),
                      // Exportación (solo admin) — mismo lenguaje visual que el resto del módulo
                      if (isAdmin)
                        SafeArea(
                          minimum: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDesignTokens.horizontalPadding,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: () =>
                                    _showExportReportSheet(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppDesignTokens.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Exportar reporte',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VotoWaveHeader(
                title: 'Resultados',
                subtitle: subtitle,
                onBack: () => Navigator.pop(context),
                trailing: isAdmin
                    ? Padding(
                        padding: const EdgeInsets.only(right: 4, top: 2),
                        child: IconButton(
                          icon: const Icon(Icons.history_rounded,
                              color: Colors.white),
                          tooltip: 'Historial de eventos',
                          onPressed: () =>
                              Navigator.pushNamed(context, '/voto/event_history'),
                        ),
                      )
                    : null,
              ),
              Expanded(child: inner()),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, String type) async {
    final confirmed = await _confirmResultsExport(context, type);
    if (!confirmed || !context.mounted) return;

    try {
      debugPrint('Iniciando exportación: $type');

      // Mostrar loading simple
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generando...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Usar loadResultsBootstrap para obtener datos instantáneamente (caché local)
      debugPrint('Cargando datos de resultados...');
      final bootstrap = await _electionService
          .loadResultsBootstrap(widget.electionId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw Exception('Timeout: no se pudieron cargar los datos'),
          );

      final election = bootstrap.election;
      if (election == null) {
        throw Exception('Elección no encontrada');
      }

      final candidates = bootstrap.candidates;
      debugPrint('Datos cargados: ${candidates.length} candidatos');

      if (candidates.isEmpty) {
        throw Exception('No hay candidatos en esta elección');
      }

      // Procesar datos directamente
      final sortedCandidates = List<Candidate>.from(candidates)
        ..sort((a, b) => b.voteCount.compareTo(a.voteCount));
      final totalVotes = sortedCandidates.fold<int>(
        0,
        (sum, c) => sum + c.voteCount,
      );

      debugPrint('Generando $type...');

      // Generar PDF o CSV con timeout
      Uint8List? pdfBytes;
      String? csv;
      String electionTitle = election.title;

      if (type == 'pdf') {
        final branding = await AppBrandingService().getReportBrandingOnce();
        final logoBytes =
            await AppBrandingService.loadReportLogoBytes(branding?.reportLogoUrl);
        final generator = ElectionReportGenerator(
          election: election,
          candidates: sortedCandidates,
          totalVotes: totalVotes,
          reportLogoBytes: logoBytes,
        );
        pdfBytes = await generator.generateReport().timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw Exception('Timeout: la generación del PDF tardó demasiado'),
        );
      } else {
        final sb = StringBuffer();
        sb.writeln('SISTEMA DE VOTACIÓN ELECTRÓNICA - SINDICATO');
        sb.writeln('REPORTE DE RESULTADOS');
        sb.writeln('');
        sb.writeln('Elección:,${election.title}');
        sb.writeln('Descripción:,${election.description.replaceAll(",", " ")}');
        sb.writeln('Fecha de generación:,${DateTime.now().toString()}');
        sb.writeln('Total de votos:,$totalVotes');
        sb.writeln('');
        sb.writeln('Resultados detallados:');
        sb.writeln('Posición,Candidato,Votos,Porcentaje');

        for (var i = 0; i < sortedCandidates.length; i++) {
          final c = sortedCandidates[i];
          final pct = totalVotes > 0
              ? (c.voteCount / totalVotes * 100).toStringAsFixed(2)
              : '0.00';
          sb.writeln(
            '${i + 1},${c.name.replaceAll(",", " ")},${c.voteCount},$pct%',
          );
        }
        csv = sb.toString();
      }

      if (!context.mounted) return;

      debugPrint('$type generado correctamente, abriendo panel de compartir...');

      // Cerrar loading inmediatamente
      Navigator.of(context).pop();

      final safeTitle = electionTitle
          .replaceAll(RegExp(r'[<>:"/\\|?*\n\r]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();
      final nameBase =
          safeTitle.isEmpty ? 'resultados' : 'resultados_$safeTitle';
      final stamp = DateTime.now().millisecondsSinceEpoch;

      if (type == 'pdf') {
        final fileName = '${nameBase}_$stamp.pdf';
        await Share.shareXFiles(
          [
            XFile.fromData(
              pdfBytes!,
              name: fileName,
              mimeType: 'application/pdf',
            ),
          ],
          subject: 'Resultados: $electionTitle',
          text: 'Reporte PDF de resultados de la votación.',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Usa el panel que se abrió para guardar el PDF, enviarlo por '
                'correo o subirlo a la nube.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else if (type == 'csv') {
        final fileName = '${nameBase}_$stamp.csv';
        final csvWithBom = '\uFEFF$csv';
        await Share.shareXFiles(
          [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(csvWithBom)),
              name: fileName,
              mimeType: 'text/csv',
            ),
          ],
          subject: 'Resultados CSV: $electionTitle',
          text: 'Exportación CSV de resultados de la votación.',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Usa el panel que se abrió para guardar el CSV, compartirlo o '
                'abrirlo en Excel / Hojas de cálculo.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error en _handleExport: $e');
      // Cerrar loading si está abierto
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<bool> _confirmResultsExport(BuildContext context, String type) async {
    final label = type == 'pdf' ? 'PDF' : 'CSV';
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Exportar resultados $label'),
            content: const Text(
              'Se generará el archivo y se abrirá el menú de tu dispositivo '
              '(Guardar, Compartir, Enviar por correo, etc.). Comprueba que '
              'sea la elección correcta antes de compartir.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Exportar'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ============================================================================
// WIDGETS DE UI
// ============================================================================

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.horizontalPadding),
        child: PremiumCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                'Error de conexión',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppDesignTokens.primaryDark,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppDesignTokens.bodyMuted(context),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsKpiRow extends StatelessWidget {
  const _ResultsKpiRow({
    required this.totalVotes,
    required this.participationPct,
    required this.candidatesCount,
  });

  final int totalVotes;
  final int participationPct;
  final int candidatesCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiMiniCard(
            value: '$totalVotes',
            label: 'Votos',
            valueColor: AppDesignTokens.primaryDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiMiniCard(
            value: '$participationPct%',
            label: 'Participación',
            valueColor: Colors.green.shade700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiMiniCard(
            value: '$candidatesCount',
            label: 'Candidatos',
            valueColor: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }
}

class _KpiMiniCard extends StatelessWidget {
  const _KpiMiniCard({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: valueColor,
                  fontSize: 20,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppDesignTokens.primaryDark.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
          ),
        ],
      ),
    );
  }
}

Color _liveBarColorForIndex(int index) {
  switch (index % 3) {
    case 0:
      return AppDesignTokens.primary;
    case 1:
      return Colors.blue.shade600;
    default:
      return Colors.green.shade600;
  }
}

class _LiveResultsSection extends StatelessWidget {
  const _LiveResultsSection({
    required this.candidates,
    required this.totalVotes,
  });

  final List<Candidate> candidates;
  final int totalVotes;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Resultados en vivo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppDesignTokens.primaryDark,
                ),
          ),
          const SizedBox(height: 16),
          ...candidates.asMap().entries.expand((e) {
            final i = e.key;
            final c = e.value;
            return [
              if (i > 0) ...[
                Divider(
                  height: 22,
                  thickness: 1,
                  color: AppDesignTokens.primaryDark.withValues(alpha: 0.08),
                ),
              ],
              _LiveCandidateRow(
                candidate: c,
                totalVotes: totalVotes,
                barColor: _liveBarColorForIndex(i),
              ),
            ];
          }),
        ],
      ),
    );
  }
}

class _LiveCandidateRow extends StatelessWidget {
  const _LiveCandidateRow({
    required this.candidate,
    required this.totalVotes,
    required this.barColor,
  });

  final Candidate candidate;
  final int totalVotes;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final double ratio =
        totalVotes > 0 ? candidate.voteCount / totalVotes : 0.0;
    final int pctRounded =
        totalVotes > 0 ? (candidate.voteCount * 100 / totalVotes).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          candidate.name,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppDesignTokens.primaryDark,
            fontSize: 15,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              child: Text(
                '${candidate.voteCount}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: barColor,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor:
                      AppDesignTokens.primaryDark.withValues(alpha: 0.08),
                  color: barColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$pctRounded%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppDesignTokens.primaryDark.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ObservacionesCard extends StatelessWidget {
  const _ObservacionesCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observaciones',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppDesignTokens.primaryDark,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'La candidata con mayor votación se muestra en primer lugar. '
            'Los resultados definitivos se habilitan al cierre de la elección.',
            style: AppDesignTokens.bodyMuted(context),
          ),
        ],
      ),
    );
  }
}

/// Indicador ligero cuando Firestore aún sirve caché o confirma escrituras.
class _SyncRibbon extends StatelessWidget {
  const _SyncRibbon();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesignTokens.lavanda.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppDesignTokens.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sincronizando con el servidor…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppDesignTokens.primaryDark.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResultsCard extends StatelessWidget {
  const _EmptyResultsCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
      child: Column(
        children: [
          Icon(
            Icons.how_to_vote_outlined,
            size: 56,
            color: AppDesignTokens.primary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 20),
          Text(
            'Sin votos registrados',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppDesignTokens.primaryDark,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Aún no se han registrado votos en esta elección.\nLos resultados aparecerán cuando los participantes voten.',
            style: AppDesignTokens.bodyMuted(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ResultsLockedCard extends StatelessWidget {
  const _ResultsLockedCard({required this.election});

  final Election election;

  @override
  Widget build(BuildContext context) {
    final endDate = DateTime.fromMillisecondsSinceEpoch(election.endDate);
    final endDateText =
        '${endDate.day.toString().padLeft(2, '0')}/'
        '${endDate.month.toString().padLeft(2, '0')}/'
        '${endDate.year} '
        '${endDate.hour.toString().padLeft(2, '0')}:'
        '${endDate.minute.toString().padLeft(2, '0')}';
    final lockedMessage = _lockedMessage(endDateText);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.horizontalPadding),
        child: PremiumCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_clock_rounded,
                  size: 52,
                  color: AppDesignTokens.primary.withValues(alpha: 0.75),
                ),
                const SizedBox(height: 16),
                Text(
                  'Resultados no disponibles',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppDesignTokens.primaryDark,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  lockedMessage,
                  style: AppDesignTokens.bodyMuted(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Volver'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesignTokens.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _lockedMessage(String endDateText) {
    if (!election.isActive || !election.isVisibleToVoters) {
      return 'Esta elección no está publicada para consulta de resultados.';
    }

    if (!election.showResultsAutomatically) {
      return 'La publicación automática de resultados está desactivada para esta elección.';
    }

    if (!hasElectionEnded(election)) {
      return 'Los resultados se publicarán automáticamente cuando finalice la elección: $endDateText.';
    }

    return 'Los resultados aún no están disponibles para votantes.';
  }
}
