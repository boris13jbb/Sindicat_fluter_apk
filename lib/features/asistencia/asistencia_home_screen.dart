import 'package:flutter/material.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

class AsistenciaHomeScreen extends StatelessWidget {
  const AsistenciaHomeScreen({super.key});

  static String _formatFecha(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final service = AsistenciaService();
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Control de Asistencia',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: StreamBuilder<List<EventoAsistencia>>(
        stream: service.getAllEventos(),
        builder: (context, snap) {
          final eventos = snap.data ?? [];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acciones Rápidas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.qr_code_scanner,
                            label: 'Escanear',
                            onTap: () => Navigator.pushNamed(context, '/asistencia/scanner'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.assignment_turned_in,
                            label: 'Asistencias',
                            onTap: () => Navigator.pushNamed(context, '/asistencia/asistencias'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.people,
                            label: 'Personas',
                            onTap: () => Navigator.pushNamed(context, '/asistencia/personas'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.file_download,
                            label: 'Exportar',
                            onTap: () => Navigator.pushNamed(context, '/asistencia/exportar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Eventos Recientes',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (eventos.isNotEmpty)
                              Chip(
                                label: Text('${eventos.length}'),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                              ),
                          ],
                        ),
                      ),
                      if (eventos.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_note, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
                                const SizedBox(height: 16),
                                Text('No hay eventos', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                  'Crea tu primer evento para gestionar asistencias.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: () => Navigator.pushNamed(context, '/asistencia/crear_evento'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Crear Evento'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: eventos.length,
                            itemBuilder: (context, i) {
                              final e = eventos[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    child: Text('${DateTime.fromMillisecondsSinceEpoch(e.fecha).day}', style: Theme.of(context).textTheme.titleMedium),
                                  ),
                                  title: Text(e.nombre),
                                  subtitle: Text('${_formatFecha(e.fecha)} • ${e.descripcion ?? "Sin descripción"}'),
                                  trailing: Chip(
                                    label: Text(e.tipoReunion.value, style: const TextStyle(fontSize: 10)),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onTap: () => Navigator.pushNamed(context, '/asistencia/evento_detail', arguments: e),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/asistencia/crear_evento'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 90,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
