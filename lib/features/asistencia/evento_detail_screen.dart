import 'package:flutter/material.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

class EventoDetailScreen extends StatelessWidget {
  const EventoDetailScreen({super.key, required this.evento});

  final EventoAsistencia evento;

  static String _formatFecha(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final service = AsistenciaService();
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Detalle del Evento',
        onNavigateBack: () => Navigator.pop(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar evento'),
                  content: Text('¿Eliminar "${evento.nombre}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        'Eliminar',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await service.deleteEvento(evento.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Evento eliminado')),
                  );
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evento.nombre,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatFecha(evento.fecha),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (evento.descripcion != null &&
                      evento.descripcion!.isNotEmpty)
                    Text(
                      evento.descripcion!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  Chip(label: Text(evento.tipoReunion.value)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Registros de Asistencia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<AsistenciaConDatos>>(
              stream: service.getAsistenciasPorEventoStream(evento.id),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'Sin registros aún. Usa Escanear o Registro manual.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(a.persona.nombreCompleto),
                        subtitle: Text(
                          '${a.asistencia.asistio ? "Asistió" : "No asistió"} • ${_formatFecha(a.asistencia.fechaRegistro ?? 0)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Eliminar registro'),
                                content: const Text(
                                  '¿Quitar este registro de asistencia?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await service.deleteAsistencia(a.asistencia.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Registro eliminado'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'manual',
            onPressed: () => Navigator.pushNamed(
              context,
              '/asistencia/registro_manual',
              arguments: evento,
            ),
            child: const Icon(Icons.person_add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'scan',
            onPressed: () => Navigator.pushNamed(
              context,
              '/asistencia/scanner',
              arguments: evento,
            ),
            child: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
    );
  }
}
