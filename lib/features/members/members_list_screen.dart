import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/asistencia/evento.dart';
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
  static const int _pageSize = 50;

  final MembersService _service = MembersService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  MemberStatus? _statusFilter;
  final List<Member> _pagedMembers = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastMemberDocument;
  bool _isLoadingPage = false;
  bool _hasMorePages = true;
  Object? _pageError;
  int _pageRequestId = 0;

  bool get _isSearching => _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadInitialMembersPage();
  }

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
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exportar socios (CSV)',
            onPressed: () => _exportMembersCsv(context),
          ),
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
              if (!_isSearching) {
                _loadInitialMembersPage();
              }
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
                          _loadInitialMembersPage();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                final wasSearching = _isSearching;
                setState(() => _searchQuery = value.trim());
                if (wasSearching && !_isSearching) {
                  _loadInitialMembersPage();
                }
              },
            ),
          ),

          // Lista de socios
          Expanded(
            child: _isSearching
                ? _buildSearchResultsList()
                : _buildPagedMembersList(),
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

  Future<void> _loadInitialMembersPage() {
    return _loadMembersPage(reset: true);
  }

  Future<void> _loadMembersPage({bool reset = false}) async {
    if (_isLoadingPage && !reset) return;
    final requestId = ++_pageRequestId;

    setState(() {
      _isLoadingPage = true;
      _pageError = null;
      if (reset) {
        _pagedMembers.clear();
        _lastMemberDocument = null;
        _hasMorePages = true;
      }
    });

    try {
      final page = await _service.getMembersPage(
        status: _statusFilter,
        limit: _pageSize,
        startAfterDocument: reset ? null : _lastMemberDocument,
      );

      if (!mounted || requestId != _pageRequestId) return;
      setState(() {
        _pagedMembers.addAll(page.members);
        _lastMemberDocument = page.lastDocument;
        _hasMorePages = page.hasMore;
        _isLoadingPage = false;
      });
    } catch (e) {
      if (!mounted || requestId != _pageRequestId) return;
      setState(() {
        _pageError = e;
        _isLoadingPage = false;
      });
    }
  }

  Widget _buildSearchResultsList() {
    return StreamBuilder<List<Member>>(
      stream: _service.getAllMembers(
        status: _statusFilter,
        searchQuery: _searchQuery,
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
            message: 'No se encontraron socios con "$_searchQuery"',
            onAdd: _navigateToAddMember,
          );
        }

        return _MembersListView(
          members: members,
          onEdit: _navigateToEditMember,
          onToggleStatus: _toggleMemberStatus,
        );
      },
    );
  }

  Widget _buildPagedMembersList() {
    if (_pageError != null && _pagedMembers.isEmpty) {
      return _ErrorState(
        message: _pageError.toString(),
        onRetry: _loadInitialMembersPage,
      );
    }

    if (_isLoadingPage && _pagedMembers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pagedMembers.isEmpty) {
      return _EmptyState(
        message: 'No hay socios registrados',
        onAdd: _navigateToAddMember,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialMembersPage,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _pagedMembers.length + 1,
        itemBuilder: (context, index) {
          if (index == _pagedMembers.length) {
            return _MembersPageFooter(
              count: _pagedMembers.length,
              hasMore: _hasMorePages,
              isLoading: _isLoadingPage,
              error: _pageError,
              onLoadMore: () => _loadMembersPage(),
              onRetry: () => _loadMembersPage(),
            );
          }

          final member = _pagedMembers[index];
          return _MemberCard(
            member: member,
            onTap: () => _navigateToEditMember(member),
            onDeactivate: () => _toggleMemberStatus(member),
          );
        },
      ),
    );
  }

  Future<void> _exportMembersCsv(BuildContext context) async {
    try {
      final list = await _service.getAllMembers().first;
      final csv = MembersService.buildMembersExportCsv(list);
      await Share.share(csv, subject: 'Exportación socios');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToAddMember() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const MemberFormScreen()),
    );

    if (result == true && mounted) {
      if (!_isSearching) {
        await _loadInitialMembersPage();
        if (!mounted) return;
      }
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
      if (!_isSearching) {
        await _loadInitialMembersPage();
        if (!mounted) return;
      }
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
          if (!_isSearching) {
            await _loadInitialMembersPage();
            if (!mounted) return;
          }
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

class _MembersListView extends StatelessWidget {
  const _MembersListView({
    required this.members,
    required this.onEdit,
    required this.onToggleStatus,
  });

  final List<Member> members;
  final void Function(Member member) onEdit;
  final void Function(Member member) onToggleStatus;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return _MemberCard(
          member: member,
          onTap: () => onEdit(member),
          onDeactivate: () => onToggleStatus(member),
        );
      },
    );
  }
}

class _MembersPageFooter extends StatelessWidget {
  const _MembersPageFooter({
    required this.count,
    required this.hasMore,
    required this.isLoading,
    required this.error,
    required this.onLoadMore,
    required this.onRetry,
  });

  final int count;
  final bool hasMore;
  final bool isLoading;
  final Object? error;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              'No se pudo cargar la siguiente página',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.expand_more),
            label: const Text('Cargar más socios'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'Mostrando $count socio(s)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

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
            if (member.modalidad != null)
              Text(
                JustificacionHelper.etiquetaModalidad(member.modalidad!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
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
