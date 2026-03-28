import 'package:flutter/material.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/models/asistencia/persona.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

class RegistroManualScreen extends StatefulWidget {
  const RegistroManualScreen({super.key, required this.evento});

  final EventoAsistencia evento;

  @override
  State<RegistroManualScreen> createState() => _RegistroManualScreenState();
}

class _RegistroManualScreenState extends State<RegistroManualScreen> {
  final _service = AsistenciaService();
  PersonaAsistencia? _personaSeleccionada;
  bool _asistio = true;
  final _justificacionController = TextEditingController();
  bool _usarNueva = false;
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _identificadorController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _justificacionController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _identificadorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Registro Manual',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Evento: ${widget.evento.nombre}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Persona existente')),
                ButtonSegment(value: true, label: Text('Nueva persona')),
              ],
              selected: {_usarNueva},
              onSelectionChanged: (s) => setState(() => _usarNueva = s.first),
            ),
            const SizedBox(height: 16),
            if (_usarNueva) ...[
              TextField(
                controller: _nombresController,
                decoration: const InputDecoration(labelText: 'Nombres *'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _apellidosController,
                decoration: const InputDecoration(labelText: 'Apellidos *'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _identificadorController,
                decoration: const InputDecoration(
                  labelText: 'Identificador (opcional)',
                ),
              ),
            ] else
              StreamBuilder<List<PersonaAsistencia>>(
                stream: _service.getAllPersonas(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox(height: 48);
                  final personas = snap.data!
                    ..sort((a, b) => a.apellidos.compareTo(b.apellidos));
                  return DropdownButtonFormField<PersonaAsistencia>(
                    initialValue: _personaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar persona *',
                    ),
                    items: personas
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.nombreCompleto),
                          ),
                        )
                        .toList(),
                    onChanged: (p) => setState(() => _personaSeleccionada = p),
                  );
                },
              ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Asistió'),
              value: _asistio,
              onChanged: (v) => setState(() => _asistio = v),
            ),
            TextField(
              controller: _justificacionController,
              decoration: const InputDecoration(
                labelText: 'Justificación *',
                hintText: 'Motivo del registro',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _loading ? null : _guardar,
            child: _loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar Asistencia'),
          ),
        ),
      ),
    );
  }

  bool get _puedeGuardar {
    if (_justificacionController.text.trim().isEmpty) return false;
    if (_usarNueva) {
      return _nombresController.text.trim().isNotEmpty &&
          _apellidosController.text.trim().isNotEmpty;
    }
    return _personaSeleccionada != null;
  }

  Future<void> _guardar() async {
    if (!_puedeGuardar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa los campos obligatorios')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (_usarNueva) {
        final p = PersonaAsistencia(
          id: '',
          nombres: _nombresController.text.trim(),
          apellidos: _apellidosController.text.trim(),
          identificador: _identificadorController.text.trim().isEmpty
              ? null
              : _identificadorController.text.trim(),
        );
        final id = await _service.createPersona(p);
        final res = await _service.registrarAsistenciaManual(
          id,
          widget.evento.id,
          _asistio,
          _justificacionController.text.trim(),
        );
        if (res != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Asistencia registrada')),
          );
          Navigator.pop(context);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ya estaba registrado o error')),
          );
        }
      } else {
        final res = await _service.registrarAsistenciaManual(
          _personaSeleccionada!.id,
          widget.evento.id,
          _asistio,
          _justificacionController.text.trim(),
        );
        if (res != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Asistencia registrada')),
          );
          Navigator.pop(context);
        } else if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Ya estaba registrado')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
