import 'package:flutter/material.dart';
import '../../core/models/voto_event.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/event_service.dart';

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
      appBar: ProfessionalAppBar(
        title: 'Historial de Eventos',
        onNavigateBack: () => Navigator.pop(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<VotoEvent>>(
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
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final e = events[i];
              return _EventCard(event: e);
            },
          );
        },
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
      case VotoEntityType.system:
        return 'Sistema';
    }
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final VotoEvent event;

  @override
  Widget build(BuildContext context) {
    final resultColor = event.result == VotoEventResult.success
        ? Colors.green
        : event.result == VotoEventResult.failure
        ? Colors.red
        : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: resultColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.type.shortLabel,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            event.formattedDate,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          if (event.userName != null &&
                              event.userName!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Text(
                              'Por: ${event.userName}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                      if (event.errorMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Error: ${event.errorMessage}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
