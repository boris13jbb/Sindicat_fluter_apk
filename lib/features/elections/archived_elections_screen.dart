import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/election.dart';
import '../../services/election_service.dart';
import 'widgets/voto_premium_chrome.dart';
import 'election_card.dart';

/// Listado de elecciones con [Election.isArchived] == true (solo administración).
class ArchivedElectionsScreen extends StatefulWidget {
  const ArchivedElectionsScreen({super.key});

  @override
  State<ArchivedElectionsScreen> createState() =>
      _ArchivedElectionsScreenState();
}

class _ArchivedElectionsScreenState extends State<ArchivedElectionsScreen> {
  final ElectionService _electionService = ElectionService();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Election> _filter(List<Election> list, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _confirmRestore(
    BuildContext context,
    Election election,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar elección'),
        content: Text(
          '«${election.title}» volverá al listado principal del sistema de voto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await _electionService.setElectionArchived(
        electionId: election.id,
        archived: false,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restaurada: ${election.title}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo restaurar: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Election election,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar elección'),
        content: Text(
          '¿Eliminar definitivamente «${election.title}»? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await _electionService.deleteElection(election.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elección eliminada')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Archivados',
            subtitle: 'Elecciones fuera del listado principal',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: StreamBuilder<List<Election>>(
              stream: _electionService.getArchivedElections(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final archived = snapshot.data ?? [];
                final filtered = _filter(archived, _searchController.text);

                if (archived.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(
                      AppDesignTokens.horizontalPadding,
                    ),
                    children: [
                      const SizedBox(height: 32),
                      PremiumCard(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            Icon(
                              Icons.archive_outlined,
                              size: 52,
                              color: AppDesignTokens.primary.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No hay elecciones archivadas',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignTokens.primaryDark,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Desde el menú de cada elección puedes archivar las que ya no quieras mostrar en «Elecciones recientes».',
                              textAlign: TextAlign.center,
                              style: AppDesignTokens.bodyMuted(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDesignTokens.horizontalPadding,
                          12,
                          AppDesignTokens.horizontalPadding,
                          8,
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Buscar en archivados…',
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
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'Ninguna coincide con la búsqueda.',
                            style: AppDesignTokens.bodyMuted(context),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 48),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final election = filtered[index];
                              return ElectionCard(
                                election: election,
                                isAdmin: true,
                                listIsArchived: true,
                                onVote: () {},
                                onDashboard: () => Navigator.pushNamed(
                                  context,
                                  '/voto/results',
                                  arguments: election.id,
                                ),
                                onEdit: () => Navigator.pushNamed(
                                  context,
                                  '/voto/edit_election',
                                  arguments: election.id,
                                ),
                                onAddCandidate: () => Navigator.pushNamed(
                                  context,
                                  '/voto/add_candidate',
                                  arguments: election.id,
                                ),
                                onViewResults: () => Navigator.pushNamed(
                                  context,
                                  '/voto/results',
                                  arguments: election.id,
                                ),
                                onRestore: () =>
                                    _confirmRestore(context, election),
                                onDelete: () => _confirmDelete(context, election),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
