import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/election.dart';
import '../../core/models/user_role.dart';
import '../../core/security/election_visibility.dart';
import '../../providers/auth_provider.dart';
import '../../services/election_service.dart';
import '../../services/members_service.dart';
import 'election_card.dart';

class ElectionsScreen extends StatefulWidget {
  const ElectionsScreen({super.key});

  @override
  State<ElectionsScreen> createState() => _ElectionsScreenState();
}

class _ElectionsScreenState extends State<ElectionsScreen> {
  final ElectionService _electionService = ElectionService();
  final MembersService _membersService = MembersService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listSectionKey = GlobalKey();
  late final Future<int> _activeMembersCountFuture;
  int _retryTick = 0;

  @override
  void initState() {
    super.initState();
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

  void _scrollToListSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _listSectionKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  /// Lleva la vista a «Elecciones recientes». Si hay búsqueda sin coincidencias, orienta al usuario.
  void _openEleccionesQuickAction(List<Election> filtered) {
    _scrollToListSection();
    final q = _searchController.text.trim();
    if (!mounted || q.isEmpty || filtered.isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No hay elecciones que coincidan con la búsqueda. '
            'Limpia el filtro para ver la lista.',
          ),
          action: SnackBarAction(
            label: 'Limpiar filtro',
            onPressed: () {
              _searchController.clear();
              setState(() {});
              _scrollToListSection();
            },
          ),
        ),
      );
    });
  }

  static String _electionStatusLine(Election e) {
    if (e.status == ElectionStatus.draft) return 'Borrador';
    final vs = getElectionVotingStatus(election: e);
    switch (vs) {
      case ElectionVotingStatus.open:
        return 'Activa';
      case ElectionVotingStatus.notStarted:
        return 'Programada';
      case ElectionVotingStatus.ended:
        return 'Finalizada';
      case ElectionVotingStatus.hidden:
        return 'No visible';
      case ElectionVotingStatus.inactive:
        return 'Inactiva';
    }
  }

  /// Si hay varias elecciones visibles, deja elegir cuál usar para la acción rápida.
  Future<Election?> _pickElectionForQuickAction(
    List<Election> visible, {
    required String helperText,
  }) async {
    if (visible.length <= 1) {
      return visible.isEmpty ? null : visible.single;
    }
    if (!mounted) return null;
    return showModalBottomSheet<Election>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppDesignTokens.background,
      builder: (sheetCtx) {
        final maxH = MediaQuery.sizeOf(sheetCtx).height * 0.62;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    'Elige una elección',
                    style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppDesignTokens.primaryDark,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    helperText,
                    style: AppDesignTokens.bodyMuted(sheetCtx),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = visible[i];
                      return ListTile(
                        title: Text(
                          e.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_electionStatusLine(e)),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppDesignTokens.primary.withValues(alpha: 0.5),
                        ),
                        onTap: () => Navigator.pop(sheetCtx, e),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCandidatesQuickAction(List<Election> visibleElections) async {
    final q = _searchController.text.trim();
    if (visibleElections.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            q.isEmpty
                ? 'No hay elecciones cargadas.'
                : 'No hay elecciones que coincidan con la búsqueda. Intenta limpiar el campo o elige desde la lista.',
          ),
        ),
      );
      return;
    }

    final chosen = await _pickElectionForQuickAction(
      visibleElections,
      helperText:
          'Se abre la pantalla de edición, donde puedes administrar los candidatos.',
    );
    if (chosen != null && mounted) {
      await Navigator.pushNamed(
        context,
        '/voto/edit_election',
        arguments: chosen.id,
      );
    }
  }

  Future<void> _openResultadosQuickAction(List<Election> visibleElections) async {
    final q = _searchController.text.trim();
    if (visibleElections.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            q.isEmpty
                ? 'No hay elecciones cargadas.'
                : 'No hay coincidencias con la búsqueda. Limpia el filtro para ver todas.',
          ),
        ),
      );
      return;
    }

    final chosen = await _pickElectionForQuickAction(
      visibleElections,
      helperText:
          'Verás estadísticas y el detalle de votos para la elección elegida.',
    );
    if (chosen != null && mounted) {
      await Navigator.pushNamed(
        context,
        '/voto/results',
        arguments: chosen.id,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _retry() => setState(() => _retryTick++);

  List<Election> _filterElections(List<Election> list, String query) {
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

  int _countOpen(List<Election> list) {
    return list
        .where(
          (e) =>
              getElectionVotingStatus(election: e) == ElectionVotingStatus.open,
        )
        .length;
  }

  int _countFinalizadas(List<Election> list) {
    return list
        .where(
          (e) =>
              getElectionVotingStatus(election: e) ==
              ElectionVotingStatus.ended,
        )
        .length;
  }

  int _sumVotes(List<Election> list) {
    return list.fold<int>(0, (a, e) => a + e.totalVotes);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.user?.role == UserRole.admin ||
        auth.user?.role == UserRole.superadmin;
    final role = auth.user?.role ?? UserRole.voter;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      bottomNavigationBar: _ElectionsBottomNavigation(role: role),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ElectionsWaveHeader(
            title: isAdmin ? 'Sistema de Voto' : 'Elecciones',
            subtitle: isAdmin
                ? 'Gestionar elecciones y votaciones'
                : 'Listado general',
            onBack: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
            onHistory: isAdmin
                ? () => Navigator.pushNamed(context, '/voto/event_history')
                : null,
            onLogout: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
          ),
          Expanded(
            child: StreamBuilder<List<Election>>(
              key: ValueKey(_retryTick),
              stream: isAdmin
                  ? _electionService.getAllElections()
                  : _electionService.getActiveElections(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDesignTokens.horizontalPadding),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        PremiumCard(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No se pudo cargar la lista',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppDesignTokens.primaryDark,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: AppDesignTokens.bodyMuted(context),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _retry,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppDesignTokens.primary,
                                ),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data ?? [];
                final filtered = _filterElections(all, _searchController.text);

                if (all.isEmpty) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDesignTokens.horizontalPadding),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        PremiumCard(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              Icon(
                                Icons.how_to_vote_outlined,
                                size: 56,
                                color: AppDesignTokens.primary.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isAdmin
                                    ? 'No hay elecciones registradas'
                                    : 'No hay elecciones activas',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppDesignTokens.primaryDark,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isAdmin
                                    ? 'Crea una elección con el botón «Nueva».'
                                    : 'Cuando haya una votación disponible, aparecerá aquí.',
                                textAlign: TextAlign.center,
                                style: AppDesignTokens.bodyMuted(context),
                              ),
                              if (isAdmin) ...[
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/voto/create_election',
                                  ),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Nueva elección'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppDesignTokens.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (isAdmin)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDesignTokens.horizontalPadding,
                            12,
                            AppDesignTokens.horizontalPadding,
                            8,
                          ),
                          child: _AdminDashboardHub(
                            onNuevaEleccion: () => Navigator.pushNamed(
                              context,
                              '/voto/create_election',
                            ),
                            onQuickElecciones: () =>
                                _openEleccionesQuickAction(filtered),
                            onQuickCandidatos: () =>
                                _openCandidatesQuickAction(filtered),
                            onQuickResultados: () =>
                                _openResultadosQuickAction(filtered),
                            onQuickHistorial: () => Navigator.pushNamed(
                              context,
                              '/voto/event_history',
                            ),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppDesignTokens.horizontalPadding,
                          isAdmin ? 4 : 12,
                          AppDesignTokens.horizontalPadding,
                          8,
                        ),
                        child: isAdmin
                            ? _AdminDashboardStatsRow(
                                activas: _countOpen(all),
                                votos: _sumVotes(all),
                                memberCountFuture: _activeMembersCountFuture,
                              )
                            : _VoterElectionStatsRow(
                                activas: _countOpen(all),
                                votos: _sumVotes(all),
                                finalizadas: _countFinalizadas(all),
                              ),
                      ),
                    ),
                    if (isAdmin)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDesignTokens.horizontalPadding,
                            0,
                            AppDesignTokens.horizontalPadding,
                            10,
                          ),
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/voto/create_election',
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('+ Crear nueva elección'),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDesignTokens.horizontalPadding,
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Buscar elección…',
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppDesignTokens.primaryDark.withValues(alpha: 0.45),
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
                                color: AppDesignTokens.primary.withValues(alpha: 0.14),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppDesignTokens.primary.withValues(alpha: 0.14),
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
                              horizontal: 4,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: KeyedSubtree(
                        key: _listSectionKey,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDesignTokens.horizontalPadding,
                            14,
                            AppDesignTokens.horizontalPadding,
                            6,
                          ),
                          child: Row(
                            children: [
                              Text(
                                isAdmin ? 'Elecciones recientes' : 'Elecciones',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppDesignTokens.primaryDark,
                                    ),
                              ),
                              const Spacer(),
                              if (isAdmin)
                                TextButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/voto/create_election',
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  label: const Text('Nueva'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppDesignTokens.primary,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Ninguna elección coincide con la búsqueda.',
                              textAlign: TextAlign.center,
                              style: AppDesignTokens.bodyMuted(context),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final election = filtered[index];
                              return ElectionCard(
                                election: election,
                                isAdmin: isAdmin,
                                onVote: () => Navigator.pushNamed(
                                  context,
                                  '/voto/voting',
                                  arguments: election.id,
                                ),
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
                                onDelete: () => _confirmDelete(
                                  context,
                                  election,
                                  _electionService,
                                ),
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

  Future<void> _confirmDelete(
    BuildContext context,
    Election election,
    ElectionService service,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Elección'),
        content: Text(
          '¿Estás seguro de eliminar "${election.title}"? Esta acción no se puede deshacer.',
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
    if (ok == true && context.mounted) {
      await service.deleteElection(election.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Elección eliminada')));
      }
    }
  }
}

Widget _electionStatCell(String label, String value, Color valueColor) {
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

class _VoterElectionStatsRow extends StatelessWidget {
  const _VoterElectionStatsRow({
    required this.activas,
    required this.votos,
    required this.finalizadas,
  });

  final int activas;
  final int votos;
  final int finalizadas;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _electionStatCell(
            'Activas',
            '$activas',
            Colors.green.shade700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _electionStatCell(
            'Votos',
            '$votos',
            AppDesignTokens.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _electionStatCell(
            'Finalizadas',
            '$finalizadas',
            Colors.blueGrey.shade600,
          ),
        ),
      ],
    );
  }
}

class _AdminDashboardStatsRow extends StatelessWidget {
  const _AdminDashboardStatsRow({
    required this.activas,
    required this.votos,
    required this.memberCountFuture,
  });

  final int activas;
  final int votos;
  final Future<int> memberCountFuture;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _electionStatCell(
            'Activas',
            '$activas',
            Colors.green.shade700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _electionStatCell(
            'Votos',
            '$votos',
            AppDesignTokens.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FutureBuilder<int>(
            future: memberCountFuture,
            builder: (context, snapshot) {
              final members = math.max(1, snapshot.data ?? 1);
              final pct = votos == 0
                  ? 0
                  : math.min(100, (100 * votos / members).round());
              return _electionStatCell(
                'Participación',
                '$pct%',
                Colors.blue.shade700,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminDashboardHub extends StatelessWidget {
  const _AdminDashboardHub({
    required this.onNuevaEleccion,
    required this.onQuickElecciones,
    required this.onQuickCandidatos,
    required this.onQuickResultados,
    required this.onQuickHistorial,
  });

  final VoidCallback onNuevaEleccion;
  final VoidCallback onQuickElecciones;
  final VoidCallback onQuickCandidatos;
  final VoidCallback onQuickResultados;
  final VoidCallback onQuickHistorial;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: Column(
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
                  Icons.how_to_vote_rounded,
                  color: AppDesignTokens.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Panel electoral',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppDesignTokens.primaryDark,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Administra elecciones, candidatos, votos y resultados en tiempo real.',
                style: AppDesignTokens.bodyMuted(context),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: onNuevaEleccion,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesignTokens.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Nueva elección',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Acciones rápidas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppDesignTokens.primaryDark,
              ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            _QuickActionCard(
              title: 'Elecciones',
              subtitle: 'Lista y estados',
              icon: Icons.how_to_vote_outlined,
              onTap: onQuickElecciones,
            ),
            _QuickActionCard(
              title: 'Candidatos',
              subtitle: 'Postulantes',
              icon: Icons.groups_2_outlined,
              onTap: onQuickCandidatos,
            ),
            _QuickActionCard(
              title: 'Resultados',
              subtitle: 'Estadísticas',
              icon: Icons.bar_chart_rounded,
              onTap: onQuickResultados,
            ),
            _QuickActionCard(
              title: 'Historial',
              subtitle: 'Auditoría electoral',
              icon: Icons.history_rounded,
              onTap: onQuickHistorial,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
        onTap: onTap,
        child: PremiumCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppDesignTokens.primaryDark.withValues(alpha: 0.35),
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
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppDesignTokens.primaryDark.withValues(alpha: 0.5),
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

class _ElectionsWaveHeader extends StatelessWidget {
  const _ElectionsWaveHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onLogout,
    this.onHistory,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _ElectionsWaveClipper(),
      child: Container(
        height: 178,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppDesignTokens.primaryDark,
              AppDesignTokens.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ElectionsCircleIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onHistory != null) ...[
                      _ElectionsCircleIconButton(
                        icon: Icons.history_rounded,
                        onTap: onHistory!,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _ElectionsCircleIconButton(
                      icon: Icons.logout_rounded,
                      onTap: onLogout,
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

class _ElectionsCircleIconButton extends StatelessWidget {
  const _ElectionsCircleIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

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
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: AppDesignTokens.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ElectionsWaveClipper extends CustomClipper<Path> {
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

/// Barra inferior: ítem **Voto** resaltado en esta pantalla.
class _ElectionsBottomNavigation extends StatelessWidget {
  const _ElectionsBottomNavigation({required this.role});

  final UserRole role;

  static const Color _primary = AppDesignTokens.primary;
  static const Color _muted = Color(0xFF6D6E8D);

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin || role == UserRole.superadmin;
    final canManageAttendance =
        isAdmin || role == UserRole.operadorAsistencia;
    final entries = <_ElectionsBottomNavEntry>[
      const _ElectionsBottomNavEntry(
        label: 'Inicio',
        icon: Icons.home_outlined,
        route: '__pop__',
      ),
      const _ElectionsBottomNavEntry(
        label: 'Voto',
        icon: Icons.how_to_vote_outlined,
        route: null,
      ),
      if (canManageAttendance)
        const _ElectionsBottomNavEntry(
          label: 'Asist.',
          icon: Icons.check_rounded,
          route: '/asistencia',
        ),
      if (isAdmin)
        const _ElectionsBottomNavEntry(
          label: 'Socios',
          icon: Icons.groups_rounded,
          route: '/members',
        ),
      const _ElectionsBottomNavEntry(
        label: 'Perfil',
        icon: Icons.person_outline_rounded,
        route: '/profile',
      ),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFECE5F6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14271B5E),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: entries
              .map((e) => _ElectionsBottomNavItem(entry: e))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ElectionsBottomNavEntry {
  const _ElectionsBottomNavEntry({
    required this.label,
    required this.icon,
    this.route,
  });

  final String label;
  final IconData icon;
  final String? route;
}

class _ElectionsBottomNavItem extends StatelessWidget {
  const _ElectionsBottomNavItem({required this.entry});

  final _ElectionsBottomNavEntry entry;

  @override
  Widget build(BuildContext context) {
    final isVoto = entry.route == null;
    final foreground =
        isVoto ? _ElectionsBottomNavigation._primary : _ElectionsBottomNavigation._muted;

    return Expanded(
      child: Tooltip(
        message: entry.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: isVoto
                ? null
                : () {
                    if (entry.route == '__pop__') {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    } else if (entry.route != null) {
                      Navigator.pushNamed(context, entry.route!);
                    }
                  },
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                constraints: const BoxConstraints(minHeight: 46),
                padding: EdgeInsets.symmetric(
                  horizontal: isVoto ? 10 : 4,
                  vertical: 6,
                ),
                decoration: isVoto
                    ? BoxDecoration(
                        color: AppDesignTokens.lavanda,
                        borderRadius: BorderRadius.circular(22),
                      )
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(entry.icon, color: foreground, size: 18),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        entry.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 11,
                          fontWeight: isVoto ? FontWeight.w900 : FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
