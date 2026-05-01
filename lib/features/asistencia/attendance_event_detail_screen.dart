import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/attendance_service.dart';
import 'route_args.dart';

/// Detalle y operaciones para un doc en colección **`attendance_events`**.
class AttendanceEventDetailScreen extends StatelessWidget {
  const AttendanceEventDetailScreen({super.key, required this.eventId});

  final String eventId;

  static String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final attendanceSvc = AttendanceService();

    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Evento reporte',
        onNavigateBack: () => Navigator.pop(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_list_rounded),
            tooltip: 'Ir al listado de asistencia',
            onPressed: () {
              // Siempre muestra `/asistencia` aunque el detalle se abriera sin esa
              // ruta en la pila (p. ej. deep link futuro): se conserva la raíz (`isFirst`)
              // y se apila el hub de asistencia encima.
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/asistencia',
                (route) => route.isFirst,
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('attendance_events')
                .doc(eventId)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: ${snap.error}'),
                );
              }
              if (!snap.hasData || !snap.data!.exists) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Cargando evento…'),
                    ],
                  ),
                );
              }
              final map = snap.data!.data() ?? {};
              final nombre = map['nombre'] as String? ?? '(sin nombre)';
              final fecha = (map['fecha'] as num?)?.toInt() ?? 0;
              final lugar = map['lugar'] as String? ?? '';
              final tipo = map['tipo'] as String? ?? '';
              final desc = map['descripcion'] as String?;
              return Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(_fmt(fecha)),
                      if (lugar.isNotEmpty) Text('Lugar: $lugar'),
                      if (tipo.isNotEmpty) Chip(label: Text(tipo)),
                      if (desc != null && desc.isNotEmpty) Text(desc),
                      const Divider(height: 24),
                      Text(
                        'ID interno Firestore:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      SelectableText(
                        eventId,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Registros guardados aquí aparecen en el reporte.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AsistenciaRegistro>>(
              stream: attendanceSvc.getEventAttendances(eventId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final list = snap.data;
                if (list == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Sin registros. Usa Escanear o Registro manual (modelo nuevo).',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = list[i];
                    return ListTile(
                      leading: Icon(
                        r.asistio ? Icons.check_circle : Icons.cancel,
                        color: r.asistio ? Colors.green : Colors.redAccent,
                      ),
                      title: Text('Socio (members): ${r.personaId}'),
                      subtitle: Text(
                        '${r.metodoRegistro.value}'
                        '${(r.justificacion?.trim().isNotEmpty == true) ? ' • ${r.justificacion!.trim()}' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
            heroTag: 'att_ev_report',
            tooltip: 'Ver reporte calculado',
            onPressed: () => Navigator.pushNamed(
              context,
              '/attendance/report',
              arguments: eventId,
            ),
            child: const Icon(Icons.bar_chart),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'att_ev_manual',
            tooltip: 'Registro manual (modelo nuevo)',
            onPressed: () => Navigator.pushNamed(
              context,
              '/asistencia/registro_manual',
              arguments: AsistenciaEventRouteArgs.attendance(eventId),
            ),
            child: const Icon(Icons.person_add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'att_ev_scan',
            tooltip: 'Escanear (modelo nuevo)',
            onPressed: () => Navigator.pushNamed(
              context,
              '/asistencia/scanner',
              arguments: AsistenciaEventRouteArgs.attendance(eventId),
            ),
            child: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
    );
  }
}
