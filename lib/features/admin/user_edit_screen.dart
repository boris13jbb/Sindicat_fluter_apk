import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/member.dart';
import '../../core/models/user.dart';
import '../../core/models/user_role.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../providers/auth_provider.dart';
import '../../services/users_admin_service.dart';
import 'widgets/role_assignment_sheet.dart';

/// Detalle y edición de una cuenta de usuario (superadmin).
class UserEditScreen extends StatefulWidget {
  const UserEditScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final UsersAdminService _service = UsersAdminService();
  final TextEditingController _memberSearchController = TextEditingController();

  AppUser? _user;
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  List<Member> _memberMatches = [];
  bool _searchingMembers = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _memberSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _service.getUserById(widget.userId);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _error = 'Usuario no encontrado.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _runMemberSearch() async {
    final query = _memberSearchController.text.trim();
    if (query.length < 2) {
      _showSnack('Escribe al menos 2 caracteres para buscar socios.');
      return;
    }

    setState(() => _searchingMembers = true);
    try {
      final results = await _service.searchMembersForLink(query);
      if (!mounted) return;
      setState(() => _memberMatches = results);
      if (results.isEmpty) {
        _showSnack('No se encontraron socios con ese criterio.');
      }
    } catch (e) {
      _showSnack(_messageFromError(e));
    } finally {
      if (mounted) setState(() => _searchingMembers = false);
    }
  }

  Future<void> _pickRole() async {
    final user = _user;
    if (user == null) return;

    final selected = await RoleAssignmentSheet.show(
      context,
      currentRole: user.role,
      userLabel: user.email,
    );

    if (selected != null) {
      await _changeRole(selected);
    }
  }

  Future<void> _changeRole(UserRole newRole) async {
    final user = _user;
    if (user == null || user.role == newRole) return;

    final confirmed = await _confirm(
      title: 'Cambiar rol',
      message: '¿Asignar el rol «${newRole.displayName}» a ${user.email}?',
    );
    if (!confirmed) return;

    await _runSave(
      () => _service.updateUserRole(targetUserId: user.id, newRole: newRole),
    );
  }

  Future<void> _toggleActive() async {
    final user = _user;
    if (user == null) return;

    final newActive = !user.isActive;
    final confirmed = await _confirm(
      title: newActive ? 'Reactivar usuario' : 'Desactivar usuario',
      message: newActive
          ? 'El usuario podrá iniciar sesión normalmente.'
          : 'El usuario quedará marcado como inactivo y su sesión se cerrará '
                'en el dispositivo en cuanto el backend sincronice el bloqueo.',
    );
    if (!confirmed) return;

    await _runSave(
      () => _service.setUserActive(targetUserId: user.id, isActive: newActive),
    );
  }

  Future<void> _linkMember(Member member) async {
    final user = _user;
    if (user == null) return;

    final confirmed = await _confirm(
      title: 'Vincular socio',
      message:
          '¿Vincular a ${member.fullName} (${member.memberNumber}) con ${user.email}?',
    );
    if (!confirmed) return;

    await _runSave(
      () =>
          _service.linkMemberToUser(targetUserId: user.id, memberId: member.id),
    );
    if (mounted) {
      setState(() => _memberMatches = []);
      _memberSearchController.clear();
    }
  }

  Future<void> _unlinkMember() async {
    final user = _user;
    if (user == null || user.memberId == null) return;

    final confirmed = await _confirm(
      title: 'Desvincular padrón',
      message: '¿Quitar la vinculación con el socio del padrón?',
    );
    if (!confirmed) return;

    await _runSave(() => _service.unlinkMemberFromUser(user.id));
  }

  Future<void> _sendPasswordReset() async {
    final user = _user;
    if (user == null || !user.isActive) return;

    final confirmed = await _confirm(
      title: 'Restablecer contraseña',
      message: '¿Enviar un enlace seguro de recuperación a ${user.email}?',
    );
    if (!confirmed) return;

    setState(() => _saving = true);
    try {
      final result = await _service.sendPasswordResetToUser(
        targetUserId: user.id,
      );
      if (mounted) _showSnack(result.message);
    } on UsersAdminException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(_messageFromError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runSave(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      await _loadUser();
      if (mounted) {
        _showSnack('Cambios guardados.');
      }
    } on UsersAdminException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(_messageFromError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFromError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentActorId = context.watch<AuthProvider>().user?.id;
    final isSelf = currentActorId == widget.userId;

    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Editar usuario',
        onNavigateBack: () => Navigator.pop(context, true),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: '$_error', onRetry: _loadUser)
          : _user == null
          ? const _ErrorState(message: 'Usuario no disponible.')
          : AbsorbPointer(
              absorbing: _saving,
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      _UserSummaryCard(user: _user!, isSelf: isSelf),
                      const SizedBox(height: 20),
                      Text(
                        'Rol del sistema',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isSelf)
                        const _HintBanner(
                          text:
                              'No puedes cambiar tu propio rol desde esta pantalla.',
                        )
                      else
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_user!.role.displayName),
                          subtitle: Text(_user!.role.assignmentDescription),
                          trailing: OutlinedButton(
                            onPressed: _saving ? null : _pickRole,
                            child: const Text('Cambiar rol'),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Estado de la cuenta',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: Text(_user!.isActive ? 'Activo' : 'Inactivo'),
                        subtitle: Text(
                          _user!.isActive
                              ? 'La cuenta está habilitada en Firestore.'
                              : 'La cuenta está marcada como inactiva.',
                        ),
                        value: _user!.isActive,
                        onChanged: _saving || isSelf
                            ? null
                            : (_) => _toggleActive(),
                      ),
                      if (isSelf)
                        const _HintBanner(
                          text: 'No puedes desactivar tu propia cuenta.',
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Seguridad',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!isSelf && _user!.isActive)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _sendPasswordReset,
                            icon: const Icon(Icons.lock_reset),
                            label: const Text(
                              'Enviar recuperación de contraseña',
                            ),
                          ),
                        )
                      else if (!isSelf)
                        const _HintBanner(
                          text:
                              'Solo se puede restablecer la contraseña de cuentas activas.',
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Vinculación con padrón',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_user!.memberId?.trim().isNotEmpty == true) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.link),
                          title: const Text('Socio vinculado'),
                          subtitle: Text(
                            'ID padrón: ${_user!.memberId}\n'
                            'Nº trabajador: ${_user!.employeeNumber ?? '—'}',
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _saving ? null : _unlinkMember,
                            icon: const Icon(Icons.link_off),
                            label: const Text('Desvincular socio'),
                          ),
                        ),
                        const Divider(height: 32),
                      ],
                      TextField(
                        controller: _memberSearchController,
                        decoration: InputDecoration(
                          labelText: 'Buscar socio para vincular',
                          hintText: 'Nombre, número o código de trabajador',
                          suffixIcon: IconButton(
                            onPressed: _searchingMembers
                                ? null
                                : _runMemberSearch,
                            icon: _searchingMembers
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.search),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _runMemberSearch(),
                      ),
                      const SizedBox(height: 8),
                      if (_memberMatches.isNotEmpty)
                        ..._memberMatches.map(
                          (member) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(member.fullName),
                              subtitle: Text(
                                'Nº ${member.memberNumber}'
                                '${member.workerCode != null ? ' · ${member.workerCode}' : ''}'
                                '${member.modalidad != null ? ' · ${member.modalidad!.value}' : ''}',
                              ),
                              trailing: FilledButton(
                                onPressed: _saving
                                    ? null
                                    : () => _linkMember(member),
                                child: const Text('Vincular'),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_saving)
                    const ColoredBox(
                      color: Color(0x33000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
    );
  }
}

class _UserSummaryCard extends StatelessWidget {
  const _UserSummaryCard({required this.user, required this.isSelf});

  final AppUser user;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user.displayName?.trim().isNotEmpty == true
                        ? user.displayName!.trim()
                        : 'Sin nombre',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (isSelf)
                  Chip(
                    label: const Text('Tu cuenta'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Email', value: user.email),
            _InfoRow(label: 'UID', value: user.id),
            _InfoRow(label: 'Rol actual', value: user.role.displayName),
            _InfoRow(
              label: 'Estado',
              value: user.isActive ? 'Activo' : 'Inactivo',
            ),
            if (user.phoneNumber?.trim().isNotEmpty == true)
              _InfoRow(label: 'Teléfono', value: user.phoneNumber!),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
