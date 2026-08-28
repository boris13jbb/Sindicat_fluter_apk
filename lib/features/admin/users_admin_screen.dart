import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/user.dart';
import '../../core/models/user_role.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../providers/auth_provider.dart';
import '../../services/users_admin_service.dart';
import 'widgets/role_assignment_sheet.dart';

/// Listado administrativo de cuentas (`users`) — solo superadmin.
class UsersAdminScreen extends StatefulWidget {
  const UsersAdminScreen({super.key});

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends State<UsersAdminScreen> {
  static const int _pageSize = 30;

  final UsersAdminService _service = UsersAdminService();
  final TextEditingController _searchController = TextEditingController();

  final List<AppUser> _pagedUsers = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoadingPage = false;
  bool _hasMorePages = true;
  Object? _pageError;
  int _pageRequestId = 0;

  UserRole? _roleFilter;
  bool? _activeFilter;
  String _searchQuery = '';
  List<AppUser>? _searchResults;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadInitialPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPage() async {
    final requestId = ++_pageRequestId;
    setState(() {
      _isLoadingPage = true;
      _pageError = null;
      _pagedUsers.clear();
      _lastDocument = null;
      _hasMorePages = true;
    });

    try {
      final page = await _service.fetchUsersPage(
        roleFilter: _roleFilter,
        activeFilter: _activeFilter,
        limit: _pageSize,
      );
      if (!mounted || requestId != _pageRequestId) return;
      setState(() {
        _pagedUsers.addAll(page.users);
        _lastDocument = page.lastDocument;
        _hasMorePages = page.hasMore;
      });
    } catch (e) {
      if (!mounted || requestId != _pageRequestId) return;
      setState(() => _pageError = e);
    } finally {
      if (mounted && requestId == _pageRequestId) {
        setState(() => _isLoadingPage = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingPage || !_hasMorePages || _lastDocument == null) return;

    final requestId = ++_pageRequestId;
    setState(() {
      _isLoadingPage = true;
      _pageError = null;
    });

    try {
      final page = await _service.fetchUsersPage(
        startAfter: _lastDocument,
        roleFilter: _roleFilter,
        activeFilter: _activeFilter,
        limit: _pageSize,
      );
      if (!mounted || requestId != _pageRequestId) return;
      setState(() {
        _pagedUsers.addAll(page.users);
        _lastDocument = page.lastDocument;
        _hasMorePages = page.hasMore;
      });
    } catch (e) {
      if (!mounted || requestId != _pageRequestId) return;
      setState(() => _pageError = e);
    } finally {
      if (mounted && requestId == _pageRequestId) {
        setState(() => _isLoadingPage = false);
      }
    }
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    setState(() {
      _searchQuery = trimmed;
      _searchResults = null;
      _isSearching = trimmed.isNotEmpty;
    });

    if (trimmed.isEmpty) {
      await _loadInitialPage();
      return;
    }

    try {
      final results = await _service.searchUsers(trimmed);
      if (!mounted || _searchQuery != trimmed) return;
      setState(() => _searchResults = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pageError = e);
    }
  }

  Future<void> _assignRoleQuick(AppUser user) async {
    final actorId = context.read<AuthProvider>().user?.id;
    if (actorId == user.id) {
      _showSnack('No puedes cambiar tu propio rol desde aquí.');
      return;
    }

    final selected = await RoleAssignmentSheet.show(
      context,
      currentRole: user.role,
      userLabel: user.email,
    );
    if (selected == null || selected == user.role) return;

    try {
      await _service.updateUserRole(targetUserId: user.id, newRole: selected);
      _showSnack('Rol actualizado a ${selected.displayName}.');
      if (_isSearching) {
        await _runSearch(_searchQuery);
      } else {
        await _loadInitialPage();
      }
    } on UsersAdminException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('$e');
    }
  }

  Future<void> _sendPasswordReset(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: Text(
          '¿Enviar un enlace seguro de recuperación a ${user.email}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await _service.sendPasswordResetToUser(
        targetUserId: user.id,
      );
      _showSnack(result.message);
    } on UsersAdminException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('$e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<AppUser> get _visibleUsers {
    if (_isSearching) {
      return _searchResults ?? [];
    }
    return _pagedUsers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Administración de usuarios',
        onNavigateBack: () => Navigator.pop(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Invitar usuario',
            onPressed: () async {
              final created = await Navigator.pushNamed(
                context,
                '/admin/users/invite',
              );
              if (created == true) {
                if (_isSearching) {
                  await _runSearch(_searchQuery);
                } else {
                  await _loadInitialPage();
                }
              }
            },
          ),
          PopupMenuButton<UserRole?>(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'Filtrar por rol',
            onSelected: (role) {
              setState(() => _roleFilter = role);
              _loadInitialPage();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Todos los roles')),
              ...UserRole.values.map(
                (role) =>
                    PopupMenuItem(value: role, child: Text(role.displayName)),
              ),
            ],
          ),
          PopupMenuButton<bool?>(
            icon: const Icon(Icons.toggle_on_outlined),
            tooltip: 'Filtrar por estado',
            onSelected: (active) {
              setState(() => _activeFilter = active);
              _loadInitialPage();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: null, child: Text('Todos')),
              PopupMenuItem(value: true, child: Text('Activos')),
              PopupMenuItem(value: false, child: Text('Inactivos')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por email, Nº trabajador o nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _runSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: _runSearch,
              onChanged: (value) {
                if (value.trim().isEmpty && _searchQuery.isNotEmpty) {
                  _runSearch('');
                }
              },
            ),
          ),
          if (_roleFilter != null || _activeFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_roleFilter != null)
                    Chip(
                      label: Text('Rol: ${_roleFilter!.displayName}'),
                      onDeleted: () {
                        setState(() => _roleFilter = null);
                        _loadInitialPage();
                      },
                    ),
                  if (_activeFilter != null)
                    Chip(
                      label: Text(
                        _activeFilter! ? 'Solo activos' : 'Solo inactivos',
                      ),
                      onDeleted: () {
                        setState(() => _activeFilter = null);
                        _loadInitialPage();
                      },
                    ),
                ],
              ),
            ),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_pageError != null && _visibleUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                'No se pudo cargar usuarios',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('$_pageError', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadInitialPage,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSearching && _searchResults == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_visibleUsers.isEmpty && !_isLoadingPage) {
      return const Center(child: Text('No hay usuarios que coincidan.'));
    }

    return RefreshIndicator(
      onRefresh: _isSearching
          ? () => _runSearch(_searchQuery)
          : _loadInitialPage,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount:
            _visibleUsers.length + (_hasMorePages && !_isSearching ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _visibleUsers.length) {
            if (_isLoadingPage) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton(
                onPressed: _loadMore,
                child: const Text('Cargar más usuarios'),
              ),
            );
          }

          final user = _visibleUsers[index];
          return _UserListTile(
            user: user,
            isSelf: context.watch<AuthProvider>().user?.id == user.id,
            onAssignRole: () => _assignRoleQuick(user),
            onSendPasswordReset: () => _sendPasswordReset(user),
            onTap: () async {
              final changed = await Navigator.pushNamed(
                context,
                '/admin/users/edit',
                arguments: user.id,
              );
              if (changed == true) {
                if (_isSearching) {
                  await _runSearch(_searchQuery);
                } else {
                  await _loadInitialPage();
                }
              }
            },
          );
        },
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({
    required this.user,
    required this.onTap,
    required this.onAssignRole,
    required this.onSendPasswordReset,
    this.isSelf = false,
  });

  final AppUser user;
  final VoidCallback onTap;
  final VoidCallback onAssignRole;
  final VoidCallback onSendPasswordReset;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactive = !user.isActive;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: inactive
              ? theme.colorScheme.error.withValues(alpha: 0.35)
              : theme.dividerColor,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: inactive
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.primaryContainer,
          child: Icon(
            inactive ? Icons.person_off_outlined : Icons.person_outline,
            color: inactive
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _InfoChip(label: user.role.displayName),
                if (user.employeeNumber?.trim().isNotEmpty == true)
                  _InfoChip(label: 'Nº ${user.employeeNumber}'),
                if (user.memberId?.trim().isNotEmpty == true)
                  const _InfoChip(label: 'Vinculado al padrón'),
                if (inactive) const _InfoChip(label: 'Inactivo', danger: true),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'role') onAssignRole();
            if (value == 'reset') onSendPasswordReset();
            if (value == 'open') onTap();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'open', child: Text('Ver detalle')),
            if (!isSelf)
              const PopupMenuItem(value: 'role', child: Text('Asignar rol')),
            if (!isSelf && user.isActive)
              const PopupMenuItem(
                value: 'reset',
                child: Text('Restablecer contraseña'),
              ),
          ],
          child: const Icon(Icons.more_vert),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.danger = false});

  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: danger
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: danger
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
