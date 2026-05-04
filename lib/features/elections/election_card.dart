import 'package:flutter/material.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/election.dart';
import '../../core/security/election_visibility.dart';

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
    this.listIsArchived = false,
    this.onArchive,
    this.onRestore,
  });

  final Election election;
  final bool isAdmin;
  final VoidCallback onVote;
  final VoidCallback onDashboard;
  final VoidCallback onEdit;
  final VoidCallback onAddCandidate;
  final VoidCallback onViewResults;
  final VoidCallback onDelete;
  /// Listado `/voto/archived_elections`: menú reducido y toque principal a resultados.
  final bool listIsArchived;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  static String _formatDateTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _formatDateShort(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = <String>[
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
    return '${d.day} ${months[d.month - 1]}';
  }

  void _onPrimaryTap(BuildContext context) {
    if (listIsArchived) {
      onViewResults();
      return;
    }
    final votingStatus = getElectionVotingStatus(election: election);
    switch (votingStatus) {
      case ElectionVotingStatus.open:
        onVote();
        break;
      case ElectionVotingStatus.ended:
        onViewResults();
        break;
      case ElectionVotingStatus.notStarted:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta elección aún no ha iniciado.')),
        );
        break;
      case ElectionVotingStatus.hidden:
      case ElectionVotingStatus.inactive:
      case ElectionVotingStatus.archived:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(electionVotingStatusMessage(votingStatus))),
        );
        break;
    }
  }

  ({Color dot, Color badgeBg, Color badgeFg, String badgeLabel, String subtitle})
      _presentation(BuildContext context) {
    if (election.status == ElectionStatus.draft) {
      return (
        dot: Colors.orange.shade600,
        badgeBg: const Color(0xFFFFF3E0),
        badgeFg: Colors.orange.shade900,
        badgeLabel: 'Borrador',
        subtitle: 'Borrador · requiere revisión',
      );
    }

    final vs = getElectionVotingStatus(election: election);
    switch (vs) {
      case ElectionVotingStatus.open:
        final end = DateTime.fromMillisecondsSinceEpoch(election.endDate);
        final hm =
            '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
        return (
          dot: Colors.green.shade600,
          badgeBg: const Color(0xFFE8F5E9),
          badgeFg: Colors.green.shade900,
          badgeLabel: 'Activa',
          subtitle: 'Activa · cierre $hm',
        );
      case ElectionVotingStatus.notStarted:
        return (
          dot: Colors.blue.shade600,
          badgeBg: const Color(0xFFE3F2FD),
          badgeFg: Colors.blue.shade900,
          badgeLabel: 'Programada',
          subtitle: 'Programada · ${_formatDateShort(election.startDate)}',
        );
      case ElectionVotingStatus.ended:
        return (
          dot: Colors.blueGrey.shade400,
          badgeBg: const Color(0xFFF1F3F8),
          badgeFg: Colors.blueGrey.shade800,
          badgeLabel: 'Finalizada',
          subtitle: 'Finalizada · resultados listos',
        );
      case ElectionVotingStatus.hidden:
        return (
          dot: Colors.blueGrey.shade300,
          badgeBg: const Color(0xFFF1F3F8),
          badgeFg: Colors.blueGrey.shade800,
          badgeLabel: 'No visible',
          subtitle: 'No visible para votantes',
        );
      case ElectionVotingStatus.inactive:
        return (
          dot: Colors.blueGrey.shade300,
          badgeBg: const Color(0xFFF1F3F8),
          badgeFg: Colors.blueGrey.shade800,
          badgeLabel: 'Inactiva',
          subtitle: 'Inactiva · ${_formatDateTime(election.startDate)}',
        );
      case ElectionVotingStatus.archived:
        return (
          dot: Colors.blueGrey.shade500,
          badgeBg: const Color(0xFFECEFF1),
          badgeFg: Colors.blueGrey.shade900,
          badgeLabel: 'Archivada',
          subtitle: 'Archivada · no visible en el listado principal',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = _presentation(context);
    final p = listIsArchived
        ? (
            dot: Colors.blueGrey.shade500,
            badgeBg: const Color(0xFFE8EAF6),
            badgeFg: AppDesignTokens.primaryDark,
            badgeLabel: 'Archivada',
            subtitle: '${base.subtitle} · carpeta archivados',
          )
        : base;

    return PremiumCard(
      margin: const EdgeInsets.fromLTRB(
        AppDesignTokens.horizontalPadding,
        0,
        AppDesignTokens.horizontalPadding,
        12,
      ),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
          onTap: () => _onPrimaryTap(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                        color: p.dot,
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
                        election.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppDesignTokens.primaryDark,
                              height: 1.2,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppDesignTokens.primaryDark
                                  .withValues(alpha: 0.55),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: p.badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    p.badgeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: p.badgeFg,
                    ),
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: AppDesignTokens.primaryDark.withValues(alpha: 0.45),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onSelected: (value) {
                      switch (value) {
                        case 'dashboard':
                          onDashboard();
                          break;
                        case 'edit':
                          onEdit();
                          break;
                        case 'add':
                          onAddCandidate();
                          break;
                        case 'results':
                          onViewResults();
                          break;
                        case 'archive':
                          onArchive?.call();
                          break;
                        case 'restore':
                          onRestore?.call();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (ctx) => listIsArchived
                        ? [
                            PopupMenuItem(
                              value: 'restore',
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.unarchive_outlined,
                                  color: AppDesignTokens.primary,
                                ),
                                title: const Text('Restaurar'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'results',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.bar_chart_outlined),
                                title: Text('Ver resultados'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(ctx).colorScheme.error,
                                ),
                                title: Text(
                                  'Eliminar',
                                  style: TextStyle(
                                    color: Theme.of(ctx).colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          ]
                        : [
                            const PopupMenuItem(
                              value: 'dashboard',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.dashboard_outlined),
                                title: Text('Dashboard'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Editar'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'add',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.person_add_outlined),
                                title: Text('Agregar candidatos'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'results',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.bar_chart_outlined),
                                title: Text('Ver resultados'),
                              ),
                            ),
                            if (onArchive != null)
                              PopupMenuItem(
                                value: 'archive',
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.archive_outlined,
                                    color: AppDesignTokens.primaryDark,
                                  ),
                                  title: const Text('Archivar'),
                                ),
                              ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(ctx).colorScheme.error,
                                ),
                                title: Text(
                                  'Eliminar',
                                  style: TextStyle(
                                    color: Theme.of(ctx).colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          ],
                  ),
                ],
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
