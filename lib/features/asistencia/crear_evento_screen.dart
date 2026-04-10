import 'package:flutter/material.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

class CrearEventoAsistenciaScreen extends StatefulWidget {
  const CrearEventoAsistenciaScreen({super.key});

  @override
  State<CrearEventoAsistenciaScreen> createState() =>
      _CrearEventoAsistenciaScreenState();
}

class _CrearEventoAsistenciaScreenState
    extends State<CrearEventoAsistenciaScreen> {
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  TipoReunion _tipo = TipoReunion.ordinaria;
  Modalidad? _modalidad;
  DateTime _fecha = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
    );
    if (time == null || !mounted) return;
    setState(() {
      _fecha = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Crear Evento',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos del evento',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del evento *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('Ordinaria'),
                          selected: _tipo == TipoReunion.ordinaria,
                          onSelected: (_) =>
                              setState(() => _tipo = TipoReunion.ordinaria),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Extraordinaria'),
                          selected: _tipo == TipoReunion.extraordinaria,
                          onSelected: (_) => setState(
                            () => _tipo = TipoReunion.extraordinaria,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _pickDate,
                      child: const Text('Seleccionar Fecha y Hora'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fecha: ${_fecha.day}/${_fecha.month}/${_fecha.year} ${_fecha.hour.toString().padLeft(2, '0')}:${_fecha.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    // 🆕 Selección de Modalidad de Turno
                    Row(
                      children: [
                        Text(
                          'Modalidad de Turno:',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<Modalidad>(
                            value: _modalidad,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            hint: const Text('Seleccionar modalidad'),
                            items: Modalidad.values.map((modalidad) {
                              return DropdownMenuItem(
                                value: modalidad,
                                child: Text(
                                  JustificacionHelper.obtenerDescripcionModalidad(modalidad),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _modalidad = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_modalidad != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                JustificacionHelper.obtenerJustificacion(_modalidad!),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.blue.shade800,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(
                onPressed: () async {
                  if (_nombreController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El nombre es obligatorio')),
                    );
                    return;
                  }
                  setState(() => _loading = true);
                  try {
                    final service = AsistenciaService();
                    final evento = EventoAsistencia(
                      id: '',
                      nombre: _nombreController.text.trim(),
                      fecha: _fecha.millisecondsSinceEpoch,
                      tipoReunion: _tipo,
                      descripcion: _descripcionController.text.trim().isEmpty
                          ? null
                          : _descripcionController.text.trim(),
                      modalidad: _modalidad,
                    );
                    await service.createEvento(evento);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Evento creado')),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: const Text('Guardar'),
              ),
          ],
        ),
      ),
    );
  }
}
