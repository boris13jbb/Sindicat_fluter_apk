import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models/election.dart';
import '../../core/models/candidate.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/election_service.dart';
import '../../core/widgets/professional_app_bar.dart';

class ElectionResultsScreen extends StatefulWidget {
  const ElectionResultsScreen({super.key, required this.electionId});

  final String electionId;

  @override
  State<ElectionResultsScreen> createState() => _ElectionResultsScreenState();
}

class _ElectionResultsScreenState extends State<ElectionResultsScreen> {
  final ElectionService _electionService = ElectionService();

  static String _toCsv(Election election, List<Candidate> sortedCandidates, int totalVotes) {
    final sb = StringBuffer();
    sb.writeln('Elección,${election.title}');
    sb.writeln('Descripción,${election.description.replaceAll(",", " ")}');
    sb.writeln('Total votos,$totalVotes');
    sb.writeln('Puesto,Candidato,Votos,Porcentaje');
    for (var i = 0; i < sortedCandidates.length; i++) {
      final c = sortedCandidates[i];
      final pct = totalVotes > 0 ? (c.voteCount / totalVotes * 100).toStringAsFixed(1) : '0';
      sb.writeln('${i + 1},${c.name.replaceAll(",", " ")},${c.voteCount},$pct%');
    }
    return sb.toString();
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
                  onPressed: () => Navigator.pushNamed(context, '/voto/event_history'),
                ),
                IconButton(
                  icon: const Icon(Icons.file_download),
                  tooltip: 'Copiar resultados en CSV',
                  onPressed: () => _exportCsv(context),
                ),
              ]
            : null,
      ),
      body: FutureBuilder<Election?>(
        future: _electionService.getElection(widget.electionId),
        builder: (context, electionSnap) {
          if (electionSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final election = electionSnap.data;
          if (election == null) {
            return const Center(child: Text('Elección no encontrada'));
          }

          return StreamBuilder<List<Candidate>>(
            stream: _electionService.getCandidates(widget.electionId),
            builder: (context, candidatesSnap) {
              if (candidatesSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final candidates = candidatesSnap.data ?? [];
              final sortedCandidates = List<Candidate>.from(candidates)
                ..sort((a, b) => b.voteCount.compareTo(a.voteCount));
              
              final totalVotes = sortedCandidates.fold<int>(0, (sum, c) => sum + c.voteCount);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderCard(
                      election: election, 
                      totalVotes: totalVotes, 
                      candidatesCount: sortedCandidates.length
                    ),
                    const SizedBox(height: 24),
                    if (sortedCandidates.isEmpty)
                      const _EmptyResultsCard()
                    else
                      ...sortedCandidates.asMap().entries.map((entry) {
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
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final election = await _electionService.getElection(widget.electionId);
    if (election == null || !context.mounted) return;
    final candidates = await _electionService.getCandidates(widget.electionId).first;
    if (!context.mounted) return;
    final sorted = List<Candidate>.from(candidates)..sort((a, b) => b.voteCount.compareTo(a.voteCount));
    final total = sorted.fold<int>(0, (s, c) => s + c.voteCount);
    final csv = _toCsv(election, sorted, total);
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resultados copiados en CSV al portapapeles')),
      );
    }
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
                _StatItem(label: 'Total Votos', value: '$totalVotes', icon: Icons.how_to_vote),
                _StatItem(label: 'Candidatos', value: '$candidatesCount', icon: Icons.people),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
    final double percentage = totalVotes > 0 ? (candidate.voteCount / totalVotes) : 0;
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: isWinner ? Colors.amber : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: isWinner 
                    ? const Icon(Icons.emoji_events, color: Colors.white)
                    : Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              title: Text(candidate.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${candidate.voteCount} votos', 
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${(percentage * 100).toStringAsFixed(1)}%', 
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                color: isWinner ? Colors.amber : Theme.of(context).colorScheme.primary,
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
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay votos registrados aún', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
