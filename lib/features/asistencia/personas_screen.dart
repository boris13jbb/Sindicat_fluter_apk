import 'package:flutter/material.dart';
import '../../core/models/asistencia/persona.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

class PersonasAsistenciaScreen extends StatefulWidget {
  const PersonasAsistenciaScreen({super.key});

  @override
  State<PersonasAsistenciaScreen> createState() =>
      _PersonasAsistenciaScreenState();
}

class _PersonasAsistenciaScreenState extends State<PersonasAsistenciaScreen> {
  final _service = AsistenciaService();
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Gestión de Personas',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o identificador',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PersonaAsistencia>>(
              stream: _service.getAllPersonas(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var list = snap.data ?? [];
                if (_busqueda.trim().isNotEmpty) {
                  final q = _busqueda.trim().toLowerCase();
                  list = list.where((p) {
                    return p.nombres.toLowerCase().contains(q) ||
                        p.apellidos.toLowerCase().contains(q) ||
                        (p.identificador?.toLowerCase().contains(q) ?? false);
                  }).toList();
                }
                list = list..sort((a, b) => a.apellidos.compareTo(b.apellidos));
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay personas. Agrega una con el botón +.',
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(p.nombreCompleto),
                        subtitle: Text(p.identificador ?? p.codigoQR ?? '—'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'delete') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Eliminar persona'),
                                  content: Text(
                                    '¿Eliminar a ${p.nombreCompleto}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
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
                                await _service.deletePersona(p.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Persona eliminada'),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPersonDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddPersonDialog(BuildContext context) async {
    final nombres = TextEditingController();
    final apellidos = TextEditingController();
    final identificador = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar persona'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombres,
                decoration: const InputDecoration(labelText: 'Nombres *'),
                autofocus: true,
              ),
              TextField(
                controller: apellidos,
                decoration: const InputDecoration(labelText: 'Apellidos *'),
              ),
              TextField(
                controller: identificador,
                decoration: const InputDecoration(
                  labelText: 'Identificador (opcional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (nombres.text.trim().isEmpty || apellidos.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final p = PersonaAsistencia(
        id: '',
        nombres: nombres.text.trim(),
        apellidos: apellidos.text.trim(),
        identificador: identificador.text.trim().isEmpty
            ? null
            : identificador.text.trim(),
      );
      await _service.createPersona(p);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Persona agregada')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
