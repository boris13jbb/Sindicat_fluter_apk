import 'package:flutter/material.dart';

import '../../../core/models/user_role.dart';

/// Hoja modal reutilizable para asignar roles con descripción y confirmaciones.
class RoleAssignmentSheet extends StatelessWidget {
  const RoleAssignmentSheet({
    super.key,
    required this.currentRole,
    required this.userLabel,
    this.excludeRoles = const {},
  });

  final UserRole currentRole;
  final String userLabel;
  final Set<UserRole> excludeRoles;

  static Future<UserRole?> show(
    BuildContext context, {
    required UserRole currentRole,
    required String userLabel,
    Set<UserRole> excludeRoles = const {},
  }) {
    return showModalBottomSheet<UserRole>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => RoleAssignmentSheet(
        currentRole: currentRole,
        userLabel: userLabel,
        excludeRoles: excludeRoles,
      ),
    );
  }

  Future<bool> _confirmSuperAdmin(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar superadministrador'),
        content: const Text(
          'Este rol otorga control total del sistema, incluida la '
          'administración de usuarios. ¿Confirmas la asignación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Asignar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roles = UserRole.assignableBySuperAdmin
        .where((role) => !excludeRoles.contains(role))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asignar rol',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              userLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final role = roles[index];
                  final selected = role == currentRole;

                  return Card(
                    elevation: 0,
                    color: selected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.dividerColor,
                      ),
                    ),
                    child: ListTile(
                      title: Text(role.displayName),
                      subtitle: Text(role.assignmentDescription),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: selected
                          ? null
                          : () async {
                              if (role == UserRole.superadmin) {
                                final ok = await _confirmSuperAdmin(context);
                                if (!ok || !context.mounted) return;
                              }
                              if (context.mounted) {
                                Navigator.pop(context, role);
                              }
                            },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
