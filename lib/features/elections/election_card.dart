import 'package:flutter/material.dart';
import '../../core/models/election.dart';

class ElectionCard extends StatelessWidget {
  const ElectionCard({
    super.key,
    required this.election,
    required this.isAdmin,
    required this.onVote,
    required this.onDashboard,
    required this.onEdit,
    required this.onAddCandidate,
    required this.onViewResults,
    required this.onDelete,
  });

  final Election election;
  final bool isAdmin;
  final VoidCallback onVote;
  final VoidCallback onDashboard;
  final VoidCallback onEdit;
  final VoidCallback onAddCandidate;
  final VoidCallback onViewResults;
  final VoidCallback onDelete;

  static String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isEnded = now > election.endDate;
    final isNotStarted = now < election.startDate;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              election.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (election.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                election.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inicio', style: Theme.of(context).textTheme.labelMedium),
                      Text(_formatDate(election.startDate),
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fin', style: Theme.of(context).textTheme.labelMedium),
                      Text(_formatDate(election.endDate),
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (isEnded)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onViewResults,
                      icon: const Icon(Icons.bar_chart, size: 20),
                      label: const Text('Ver Resultados'),
                    ),
                  )
                else if (isNotStarted)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.schedule, size: 20),
                      label: const Text('Aún no inicia'),
                    ),
                  )
                else
                  Expanded(
                    child: FilledButton(
                      onPressed: onVote,
                      child: const Text('Votar'),
                    ),
                  ),
                if (isAdmin)
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: onDashboard,
                      child: const Text('Dashboard'),
                    ),
                  ),
              ],
            ),
            if (isAdmin) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete, size: 18, color: Theme.of(context).colorScheme.error),
                      label: Text('Eliminar', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddCandidate,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Agregar Candidatos'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
