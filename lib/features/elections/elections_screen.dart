import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/election.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/election_service.dart';
import '../../core/widgets/professional_app_bar.dart';
import 'election_card.dart';

class ElectionsScreen extends StatefulWidget {
  const ElectionsScreen({super.key});

  @override
  State<ElectionsScreen> createState() => _ElectionsScreenState();
}

class _ElectionsScreenState extends State<ElectionsScreen> {
  final ElectionService _electionService = ElectionService();
  int _retryTick = 0;

  void _retry() => setState(() => _retryTick++);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.user?.role == UserRole.admin;

    return Scaffold(
      appBar: ProfessionalAppBar(
        title: isAdmin ? 'Todas las Elecciones' : 'Elecciones Activas',
        onNavigateBack: () => Navigator.pop(context),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Historial de eventos',
              onPressed: () =>
                  Navigator.pushNamed(context, '/voto/event_history'),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
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
        ],
      ),
      body: StreamBuilder<List<Election>>(
        key: ValueKey(_retryTick),
        stream: isAdmin
            ? _electionService.getAllElections()
            : _electionService.getActiveElections(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final elections = snapshot.data ?? [];
          if (elections.isEmpty) {
            return Center(
              child: Text(
                isAdmin
                    ? 'No hay elecciones registradas'
                    : 'No hay elecciones activas',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: elections.length,
            itemBuilder: (context, index) {
              final election = elections[index];
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
                onDelete: () =>
                    _confirmDelete(context, election, _electionService),
              );
            },
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/voto/create_election'),
              child: const Icon(Icons.add),
            )
          : null,
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
