import 'package:flutter/material.dart';
import '../../core/models/member.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/members_service.dart';
import 'member_form_screen.dart';

/// Pantalla de lista de socios/miembros
class MembersListScreen extends StatefulWidget {
  const MembersListScreen({super.key});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final MembersService _service = MembersService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  MemberStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Gestión de Socios',
        onNavigateBack: () => Navigator.pop(context),
        actions: [
          // 🆕 Botón de importación
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Importar socios desde CSV',
            onPressed: () => Navigator.pushNamed(context, '/members/import'),
          ),
          // Filtro por estado
          PopupMenuButton<MemberStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() => _statusFilter = status);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Todos')),
              const PopupMenuItem(
                value: MemberStatus.active,
                child: Text('Activos'),
              ),
              const PopupMenuItem(
                value: MemberStatus.inactive,
                child: Text('Inactivos'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar socio...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.trim());
              },
            ),
          ),

          // Lista de socios
          Expanded(
            child: StreamBuilder<List<Member>>(
              stream: _service.getAllMembers(
                status: _statusFilter,
                searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: snapshot.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final members = snapshot.data!;

                if (members.isEmpty) {
                  return _EmptyState(
                    message: _searchQuery.isNotEmpty
                        ? 'No se encontraron socios con "$_searchQuery"'
                        : 'No hay socios registrados',
                    onAdd: _navigateToAddMember,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _MemberCard(
                      member: member,
                      onTap: () => _navigateToEditMember(member),
                      onDeactivate: () => _toggleMemberStatus(member),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddMember,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Socio'),
      ),
    );
  }

  void _navigateToAddMember() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const MemberFormScreen()),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Socio creado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _navigateToEditMember(Member member) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => MemberFormScreen(member: member)),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Socio actualizado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _toggleMemberStatus(Member member) async {
    final shouldToggle = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          member.status == MemberStatus.active
              ? 'Desactivar Socio'
              : 'Reactivar Socio',
        ),
        content: Text(
          member.status == MemberStatus.active
              ? '¿Estás seguro de desactivar a ${member.fullName}?'
              : '¿Estás seguro de reactivar a ${member.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              member.status == MemberStatus.active ? 'Desactivar' : 'Reactivar',
            ),
          ),
        ],
      ),
    );

    if (shouldToggle == true && mounted) {
      try {
        if (member.status == MemberStatus.active) {
          await _service.deactivateMember(member.id);
        } else {
          await _service.reactivateMember(member.id);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                member.status == MemberStatus.active
                    ? 'Socio desactivado'
                    : 'Socio reactivado',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

// ==================== WIDGETS AUXILIARES ====================

class _MemberCard extends StatelessWidget {
  final Member member;
  final VoidCallback onTap;
  final VoidCallback onDeactivate;

  const _MemberCard({
    required this.member,
    required this.onTap,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = member.status == MemberStatus.active;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green : Colors.grey,
          child: Text(
            member.firstName.isNotEmpty
                ? member.firstName[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          member.fullName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? null : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('N° Socio: ${member.memberNumber}'),
            if (member.documentId != null)
              Text('Documento: ${member.documentId}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'deactivate') {
              onDeactivate();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'deactivate',
              child: Text(
                isActive ? 'Desactivar' : 'Reactivar',
                style: TextStyle(color: isActive ? Colors.red : Colors.green),
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback onAdd;

  const _EmptyState({required this.message, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add),
            label: const Text('Agregar Socio'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar socios',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
