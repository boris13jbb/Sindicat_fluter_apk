import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../core/models/election.dart';
import '../../core/models/candidate.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/election_service.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../core/reports/election_report_generator.dart';

class ElectionResultsScreen extends StatefulWidget {
  const ElectionResultsScreen({super.key, required this.electionId});

  final String electionId;

  @override
  State<ElectionResultsScreen> createState() => _ElectionResultsScreenState();
}

class _ElectionResultsScreenState extends State<ElectionResultsScreen> {
  late ElectionService _electionService;
  late Future<ResultsBootstrap> _bootstrap;

  static const Duration _bootstrapTimeout = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _electionService = ElectionService();
    _bootstrap = _loadBootstrap();
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.role == UserRole.admin;
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Resultados en Tiempo Real',
        onNavigateBack: () => Navigator.pop(context),
        actions: isAdmin
            ? [
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: 'Historial de eventos',
                  onPressed: () =>
                      Navigator.pushNamed(context, '/voto/event_history'),
                ),
              ]
            : null,
      ),
      body: FutureBuilder<ResultsBootstrap>(
        future: _bootstrap,
        builder: (context, bootSnap) {
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
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Elección No Encontrada',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'La elección que buscas no existe o ha sido eliminada.\nVerifica el ID e inténtalo nuevamente.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (syncing) const _SyncRibbon(),
                              if (syncing) const SizedBox(height: 12),
                              _HeaderCard(
                                election: election,
                                totalVotes: totalVotes,
                                candidatesCount: sortedCandidates.length,
                              ),
                              const SizedBox(height: 24),
                              if (sortedCandidates.isEmpty)
                                const _EmptyResultsCard()
                              else
                                ...sortedCandidates.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final candidate = entry.value;
                                  return _ResultTile(
                                    candidate: candidate,
                                    rank: index + 1,
                                    totalVotes: totalVotes,
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                      // Botones de exportación (solo admin)
                      if (isAdmin)
                        SafeArea(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth < 400) {
                                  // Diseño vertical para pantallas pequeñas
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _handleExport(context, 'csv'),
                                          icon: const Icon(Icons.table_chart),
                                          label: const Text('Descargar CSV'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: () =>
                                              _handleExport(context, 'pdf'),
                                          icon: const Icon(
                                            Icons.picture_as_pdf,
                                          ),
                                          label: const Text('Descargar PDF'),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  // Diseño horizontal para pantallas medianas/grandes
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _handleExport(context, 'csv'),
                                          icon: const Icon(Icons.table_chart),
                                          label: const Text('Descargar CSV'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: () =>
                                              _handleExport(context, 'pdf'),
                                          icon: const Icon(
                                            Icons.picture_as_pdf,
                                          ),
                                          label: const Text('Descargar PDF'),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, String type) async {
    try {
      debugPrint('Iniciando exportación: $type');

      // Mostrar indicador de carga
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    type == 'pdf' ? 'Generando PDF...' : 'Preparando CSV...',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Procesando datos en segundo plano...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Obtener datos de Firestore en el hilo principal (con Firebase inicializado)
      debugPrint('Obteniendo datos de Firestore...');
      final election = await _electionService.getElection(widget.electionId);
      if (election == null) {
        throw Exception('Elección no encontrada');
      }

      final candidatesStream = _electionService.getCandidates(
        widget.electionId,
      );
      final candidates = await candidatesStream.first;

      debugPrint('Datos obtenidos: ${candidates.length} candidatos');

      // Ejecutar SOLO el procesamiento pesado en un isolate separado
      final result = await compute(
        _processExportData,
        _ExportParams(
          electionId: widget.electionId,
          type: type,
          election: election,
          candidates: candidates,
        ),
      );

      if (!context.mounted) return;

      debugPrint('Datos procesados en isolate: ${result.electionTitle}');

      // Mostrar resultado en hilo principal
      if (type == 'pdf') {
        await Printing.sharePdf(
          bytes: result.pdfBytes!,
          filename:
              'resultados_${result.electionTitle.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✅ PDF Generado',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Reporte de resultados exportado correctamente',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (type == 'csv') {
        await Clipboard.setData(ClipboardData(text: result.csv!));
        debugPrint('CSV copiado al portapapeles');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✅ CSV Copiado',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Resultados copiados al portapapeles',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      // Cerrar loading si aún está abierto
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error en _handleExport: $e');
      // Cerrar loading
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error al exportar: ${e.toString()}')),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class _ExportData {
  final Election election;
  final List<Candidate> candidates;

  _ExportData({required this.election, required this.candidates});
}

class _ExportParams {
  final String electionId;
  final String type;
  final Election election;
  final List<Candidate> candidates;

  _ExportParams({
    required this.electionId,
    required this.type,
    required this.election,
    required this.candidates,
  });
}

class _ExportResult {
  final Uint8List? pdfBytes;
  final String? csv;
  final String electionTitle;

  _ExportResult({this.pdfBytes, this.csv, required this.electionTitle});
}

// Función top-level para compute - procesa SOLO CPU (sin Firebase)
Future<_ExportResult> _processExportData(_ExportParams params) async {
  // Los datos YA VIENEN del hilo principal - NO usar Firebase aquí
  final election = params.election;
  final candidates = params.candidates;

  // Ordenar y procesar (solo CPU pesado)
  final sortedCandidates = List<Candidate>.from(candidates)
    ..sort((a, b) => b.voteCount.compareTo(a.voteCount));
  final totalVotes = sortedCandidates.fold<int>(
    0,
    (sum, c) => sum + c.voteCount,
  );

  if (params.type == 'pdf') {
    // Generar PDF (solo CPU)
    final generator = ElectionReportGenerator(
      election: election,
      candidates: sortedCandidates,
      totalVotes: totalVotes,
    );
    return _ExportResult(
      pdfBytes: await generator.generateReport(),
      electionTitle: election.title,
    );
  } else {
    // Generar CSV (solo CPU)
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
        '${i + 1},${c.name.replaceAll(",", " ")},${c.voteCount},${pct}%',
      );
    }

    return _ExportResult(csv: sb.toString(), electionTitle: election.title);
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
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Error de Conexión',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar Conexión'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
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
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.election,
    required this.totalVotes,
    required this.candidatesCount,
  });

  final Election election;
  final int totalVotes;
  final int candidatesCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              election.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Total Votos',
                  value: '$totalVotes',
                  icon: Icons.how_to_vote,
                ),
                _StatItem(
                  label: 'Candidatos',
                  value: '$candidatesCount',
                  icon: Icons.people,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.candidate,
    required this.rank,
    required this.totalVotes,
  });

  final Candidate candidate;
  final int rank;
  final int totalVotes;

  @override
  Widget build(BuildContext context) {
    final double percentage = totalVotes > 0
        ? (candidate.voteCount / totalVotes)
        : 0;
    final bool isWinner = rank == 1 && totalVotes > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: isWinner
            ? Border.all(color: Colors.amber.shade700, width: 2)
            : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: isWinner
                    ? Colors.amber
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: isWinner
                    ? const Icon(Icons.emoji_events, color: Colors.white)
                    : Text(
                        '#$rank',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
              title: Text(
                candidate.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${candidate.voteCount} votos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                color: isWinner
                    ? Colors.amber
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador ligero cuando Firestore aún sirve caché o confirma escrituras.
class _SyncRibbon extends StatelessWidget {
  const _SyncRibbon();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondaryContainer.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sincronizando con el servidor…',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSecondaryContainer),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(
              Icons.how_to_vote_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin Votos Registrados',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Aún no se han registrado votos en esta elección.\nLos resultados aparecerán aquí a medida que los participantes voten.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
