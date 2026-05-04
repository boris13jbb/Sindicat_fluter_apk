import 'package:flutter/material.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/voto_event.dart';
import '../../services/event_service.dart';
import '../elections/widgets/voto_premium_chrome.dart';

class EventHistoryScreen extends StatefulWidget {
  const EventHistoryScreen({super.key});

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  final EventService _service = EventService();
  VotoEntityType? _filter;

  String _getFriendlyErrorMessage(dynamic error) {
    final errorMsg = error.toString().toLowerCase();

    if (errorMsg.contains('permission') || errorMsg.contains('unauthorized')) {
      return 'No tienes permisos para ver los eventos.\nVerifica tu sesión e intenta nuevamente.';
    }

    if (errorMsg.contains('index') || errorMsg.contains('requires index')) {
      return 'Se requiere un índice en Firestore para mostrar los eventos.\nContacta al administrador.';
    }

    if (errorMsg.contains('offline') ||
        errorMsg.contains('network') ||
        errorMsg.contains('connection')) {
      return 'Sin conexión a internet.\nLos eventos se mostrarán cuando te conectes.';
    }

    return 'Error al cargar eventos:\n${error.toString()}';
  }

  bool _isOfflineError(dynamic error) {
    final errorMsg = error.toString().toLowerCase();
    return errorMsg.contains('offline') ||
        errorMsg.contains('network') ||
        errorMsg.contains('connection');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Historial',
            subtitle: 'Auditoría del módulo de voto',
            onBack: () => Navigator.pop(context),
            trailing: Padding(
              padding: const EdgeInsets.only(right: 4, top: 2),
              child: IconButton(
                icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
                tooltip: 'Filtrar por tipo',
                onPressed: () => _showFilterDialog(context),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<VotoEvent>>(
        stream: _filter == null
            ? _service.getAllEvents()
            : _service.getEventsByEntityType(_filter!),
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('❌ Error en historial de eventos: ${snap.error}');
            debugPrint('StackTrace: ${StackTrace.current}');

            final errorMessage = _getFriendlyErrorMessage(snap.error);
            final isOffline = _isOfflineError(snap.error);

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (isOffline) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Verifica tu conexión e intenta nuevamente',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}), // Reintentar
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data ?? [];
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _filter == null
                        ? 'No hay eventos registrados'
                        : 'No hay eventos de este tipo',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppDesignTokens.horizontalPadding,
              12,
              AppDesignTokens.horizontalPadding,
              24,
            ),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final e = events[i];
              return _EventCard(event: e);
            },
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    VotoEntityType? selected = _filter;
    showDialog<VotoEntityType?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filtrar eventos'),
          content: SingleChildScrollView(
            child: RadioGroup<VotoEntityType?>(
              groupValue: selected,
              onChanged: (v) => setDialogState(() => selected = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RadioListTile<VotoEntityType?>(
                    title: Text('Todos'),
                    value: null,
                  ),
                  ...VotoEntityType.values.map(
                    (t) => RadioListTile<VotoEntityType?>(
                      title: Text(_entityLabel(t)),
                      value: t,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    ).then((value) {
      setState(() => _filter = value);
    });
  }

  String _entityLabel(VotoEntityType t) {
    switch (t) {
      case VotoEntityType.user:
        return 'Usuarios';
      case VotoEntityType.election:
        return 'Elecciones';
      case VotoEntityType.candidate:
        return 'Candidatos';
      case VotoEntityType.vote:
        return 'Votos';
      case VotoEntityType.member:
        return 'Socios';
      case VotoEntityType.attendance:
        return 'Asistencia';
      case VotoEntityType.import_:
        return 'Importaciones';
      case VotoEntityType.system:
        return 'Sistema';
    }
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final VotoEvent event;

  static const Color _success = Color(0xFF2E7D32);
  static const Color _failure = Color(0xFFC62828);
  static const Color _pending = Color(0xFFEF6C00);

  @override
  Widget build(BuildContext context) {
    final resultColor = event.result == VotoEventResult.success
        ? _success
        : event.result == VotoEventResult.failure
            ? _failure
            : _pending;

    return PremiumCard(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: resultColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.lavanda.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        event.type.shortLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppDesignTokens.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppDesignTokens.primaryDark.withValues(alpha: 0.88),
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: AppDesignTokens.primaryDark.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      event.formattedDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                AppDesignTokens.primaryDark.withValues(alpha: 0.48),
                          ),
                    ),
                    if (event.userName != null &&
                        event.userName!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.person_outline_rounded,
                        size: 15,
                        color:
                            AppDesignTokens.primaryDark.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          event.userName!,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppDesignTokens.primaryDark
                                    .withValues(alpha: 0.48),
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (event.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.errorContainer.withValues(
                                alpha: 0.45,
                              ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      event.errorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
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
}
