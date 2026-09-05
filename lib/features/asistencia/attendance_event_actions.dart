import 'package:flutter/material.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/models/user_role.dart';
import '../../core/security/route_access.dart';
import '../../services/attendance_service.dart';

/// Result of an attendance-event management action.
enum AttendanceEventActionResult {
  none,
  updated,
  archived,
  unarchived,
  deleted,
  cancelled,
}

/// Centralized RBAC + confirmations for edit / archive / delete.
class AttendanceEventActions {
  AttendanceEventActions({AttendanceService? service})
    : _service = service ?? AttendanceService();

  final AttendanceService _service;

  static bool canEdit(UserRole role) => attendanceRouteRoles.contains(role);

  static bool canArchive(UserRole role) => attendanceRouteRoles.contains(role);

  /// Hard delete is SUPERADMIN-only (matches Firestore Rules + CF).
  static bool canDelete(UserRole role) => role == UserRole.superadmin;

  Future<void> showMenu({
    required BuildContext context,
    required AttendanceEvent event,
    required UserRole role,
    required void Function(AttendanceEventActionResult result) onDone,
  }) async {
    final items = <Widget>[];
    if (canEdit(role)) {
      items.add(
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Editar'),
          onTap: () {
            Navigator.pop(context, 'edit');
          },
        ),
      );
    }
    if (canArchive(role)) {
      if (event.archivado) {
        items.add(
          ListTile(
            leading: const Icon(Icons.unarchive_outlined),
            title: const Text('Desarchivar'),
            onTap: () => Navigator.pop(context, 'unarchive'),
          ),
        );
      } else {
        items.add(
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Archivar'),
            onTap: () => Navigator.pop(context, 'archive'),
          ),
        );
      }
    }
    if (canDelete(role)) {
      items.add(
        ListTile(
          leading: Icon(
            Icons.delete_outline_rounded,
            color: Colors.red.shade700,
          ),
          title: Text(
            'Eliminar',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () => Navigator.pop(context, 'delete'),
        ),
      );
    }
    if (items.isEmpty) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppDesignTokens.background,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );

    if (!context.mounted || choice == null) {
      onDone(AttendanceEventActionResult.cancelled);
      return;
    }

    switch (choice) {
      case 'edit':
        final updated = await Navigator.pushNamed(
          context,
          '/asistencia/crear_attendance_event',
          arguments: event.id,
        );
        onDone(
          updated == true
              ? AttendanceEventActionResult.updated
              : AttendanceEventActionResult.none,
        );
        return;
      case 'archive':
        onDone(await _confirmAndArchive(context, event));
        return;
      case 'unarchive':
        onDone(await _confirmAndUnarchive(context, event));
        return;
      case 'delete':
        onDone(await _confirmAndDelete(context, event));
        return;
      default:
        onDone(AttendanceEventActionResult.none);
    }
  }

  Future<AttendanceEventActionResult> _confirmAndArchive(
    BuildContext context,
    AttendanceEvent event,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivar evento'),
        content: const Text(
          'El evento dejará de aparecer en el listado principal, '
          'pero conservará todos sus registros y podrá restaurarse '
          'posteriormente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return AttendanceEventActionResult.cancelled;
    }
    return _runBusy(context, () async {
      await _service.archiveEvent(event.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Evento archivado')));
      }
      return AttendanceEventActionResult.archived;
    });
  }

  Future<AttendanceEventActionResult> _confirmAndUnarchive(
    BuildContext context,
    AttendanceEvent event,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desarchivar evento'),
        content: Text(
          '¿Restaurar «${event.nombre}» al listado de eventos activos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desarchivar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return AttendanceEventActionResult.cancelled;
    }
    return _runBusy(context, () async {
      await _service.unarchiveEvent(event.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Evento restaurado')));
      }
      return AttendanceEventActionResult.unarchived;
    });
  }

  Future<AttendanceEventActionResult> _confirmAndDelete(
    BuildContext context,
    AttendanceEvent event,
  ) async {
    final hasRecords = await _service.hasAttendanceRecords(event.id);
    if (!context.mounted) return AttendanceEventActionResult.cancelled;

    if (hasRecords) {
      final archiveInstead = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: const Text(
            'No se puede eliminar este evento porque ya contiene '
            'registros de asistencia. Archívalo para conservar el historial.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Archivar evento'),
            ),
          ],
        ),
      );
      if (archiveInstead == true && context.mounted) {
        if (event.archivado) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El evento ya está archivado')),
          );
          return AttendanceEventActionResult.none;
        }
        return _confirmAndArchive(context, event);
      }
      return AttendanceEventActionResult.cancelled;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text(
          'Esta acción eliminará definitivamente el evento '
          '«${event.nombre}» y no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return AttendanceEventActionResult.cancelled;
    }

    return _runBusy(context, () async {
      try {
        await _service.deleteEventSafely(event.id);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Evento eliminado')));
        }
        return AttendanceEventActionResult.deleted;
      } on AttendanceEventHasRecordsException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
        return AttendanceEventActionResult.none;
      } on AttendanceEventDeleteException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_humanDeleteError(e))));
        }
        return AttendanceEventActionResult.none;
      }
    });
  }

  String _humanDeleteError(AttendanceEventDeleteException e) {
    switch (e.code) {
      case 'forbidden':
        return 'No tiene permisos para eliminar este evento.';
      case 'unauthenticated':
        return 'Debe iniciar sesión nuevamente.';
      case 'event-missing':
        return 'El evento ya no existe.';
      case 'missing-app-check':
      case 'app-check-unavailable':
        return 'No se pudo verificar App Check. Intente de nuevo.';
      case 'network-error':
        return 'Error de red al eliminar el evento.';
      default:
        return 'No se pudo eliminar el evento.';
    }
  }

  Future<AttendanceEventActionResult> _runBusy(
    BuildContext context,
    Future<AttendanceEventActionResult> Function() action,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result = await action();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      return result;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_humanGenericError(e))));
      }
      return AttendanceEventActionResult.none;
    }
  }

  String _humanGenericError(Object e) {
    final raw = e.toString();
    if (raw.contains('permission-denied') ||
        raw.contains('PERMISSION_DENIED')) {
      return 'No tiene permisos para esta acción.';
    }
    if (raw.contains('Usuario no autenticado')) {
      return 'Debe iniciar sesión nuevamente.';
    }
    if (raw.contains('Evento no encontrado')) {
      return 'Evento no encontrado.';
    }
    return 'No se pudo completar la acción.';
  }
}

/// Overflow button that stops parent [InkWell] taps.
class AttendanceEventOverflowButton extends StatelessWidget {
  const AttendanceEventOverflowButton({
    super.key,
    required this.event,
    required this.role,
    required this.onDone,
    this.service,
  });

  final AttendanceEvent event;
  final UserRole role;
  final void Function(AttendanceEventActionResult result) onDone;
  final AttendanceService? service;

  @override
  Widget build(BuildContext context) {
    if (!AttendanceEventActions.canEdit(role) &&
        !AttendanceEventActions.canArchive(role) &&
        !AttendanceEventActions.canDelete(role)) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AttendanceEventActions(
          service: service,
        ).showMenu(context: context, event: event, role: role, onDone: onDone);
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.more_vert_rounded,
          color: AppDesignTokens.primaryDark.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
