import 'package:flutter/material.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

class AsistenciasListScreen extends StatefulWidget {
  const AsistenciasListScreen({super.key});

  @override
  State<AsistenciasListScreen> createState() => _AsistenciasListScreenState();
}

class _AsistenciasListScreenState extends State<AsistenciasListScreen> {
  final AsistenciaService _service = AsistenciaService();

  static String _formatFecha(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Asistencias',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: StreamBuilder<List<AsistenciaConDatos>>(
        stream: _service.watchAllAsistenciasConDatos(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_turned_in, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('No hay registros de asistencia.'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final a = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(a.persona.nombreCompleto),
                  subtitle: Text(
                    '${a.evento.nombre} • ${a.asistencia.asistio ? "Asistió" : "No asistió"} • ${_formatFecha(a.asistencia.fechaRegistro ?? 0)}',
                    maxLines: 2,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
