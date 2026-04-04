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
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 150,
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta de información del evento
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event_note,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Información del Evento',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(label: 'Nombre:', value: widget.evento.nombre),
                        _InfoRow(
                          label: 'Fecha:',
                          value: _formatDate(widget.evento.fecha),
                        ),
                        _InfoRow(
                          label: 'Tipo:',
                          value: _formatTipoReunion(
                            widget.evento.tipoReunion.value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Selector de tipo de registro
                Text(
                  'Tipo de Registro',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Persona Existente'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Nueva Persona'),
                      icon: Icon(Icons.person_add),
                    ),
                  ],
                  selected: {_usarNueva},
                  onSelectionChanged: (s) =>
                      setState(() => _usarNueva = s.first),
                ),
                const SizedBox(height: 24),
                // Campos según el tipo de registro
                if (_usarNueva) ...[
                  _buildSectionTitle(context, 'Datos de la Persona'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nombresController,
                    decoration: InputDecoration(
                      labelText: 'Nombres *',
                      hintText: 'Ingrese los nombres completos',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apellidosController,
                    decoration: InputDecoration(
                      labelText: 'Apellidos *',
                      hintText: 'Ingrese los apellidos completos',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _identificadorController,
                    decoration: InputDecoration(
                      labelText: 'Identificador (Opcional)',
                      hintText: 'Ej: DNI, Código, etc.',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ] else
                  StreamBuilder<List<PersonaAsistencia>>(
                    stream: _service.getAllPersonas(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Cargando personas...',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final personas = snap.data!
                        ..sort((a, b) => a.apellidos.compareTo(b.apellidos));
                      return DropdownButtonFormField<PersonaAsistencia>(
                        value: _personaSeleccionada,
                        decoration: InputDecoration(
                          labelText: 'Seleccionar Persona *',
                          hintText: 'Busque y seleccione una persona',
                          prefixIcon: const Icon(Icons.person_search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                        ),
                        items: personas
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p.nombreCompleto,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (p) =>
                            setState(() => _personaSeleccionada = p),
                        isExpanded: true,
                      );
                    },
                  ),
                const SizedBox(height: 24),
                // Sección de estado de asistencia
                _buildSectionTitle(context, 'Estado de Asistencia'),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Row(
                      children: [
                        Icon(
                          _asistio ? Icons.check_circle : Icons.cancel,
                          color: _asistio
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _asistio
                                ? 'La persona ASISTIÓ al evento'
                                : 'La persona NO ASISTIÓ al evento',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _asistio
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      _asistio
                          ? 'Registrado como presente'
                          : 'Registrado como ausente',
                    ),
                    value: _asistio,
                    onChanged: (v) => setState(() => _asistio = v),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    isThreeLine: true,
                  ),
                ),
                const SizedBox(height: 24),
                // Justificación
                _buildSectionTitle(context, 'Justificación'),
                const SizedBox(height: 12),
                TextField(
                  controller: _justificacionController,
                  decoration: InputDecoration(
                    labelText: 'Justificación o Motivo *',
                    hintText:
                        'Describa el motivo del registro (ej: llegó tarde, se retiró temprano, etc.)',
                    prefixIcon: const Icon(Icons.note_alt),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  minLines: 2,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const Spacer(),
                // Botón de guardar
                FilledButton.icon(
                  onPressed: _loading || !_puedeGuardar ? null : _guardar,
                  icon: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_alt),
                  label: Text(
                    _loading
                        ? 'Guardando...'
                        : 'Guardar Registro de Asistencia',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Texto de ayuda
                Text(
                  '* Los campos marcados con asterisco son obligatorios',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _InfoRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTipoReunion(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'presencial':
        return 'Presencial';
      case 'virtual':
        return 'Virtual';
      case 'hibrida':
        return 'Híbrida';
      default:
        return tipo;
    }
  }

  bool get _puedeGuardar {
    if (_justificacionController.text.trim().isEmpty) return false;
    if (_usarNueva) {
      return _nombresController.text.trim().isNotEmpty &&
          _apellidosController.text.trim().isNotEmpty;
    }
    return _personaSeleccionada != null;
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Cerrar',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_puedeGuardar) {
      _mostrarError('Por favor, complete todos los campos obligatorios (*)');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_usarNueva) {
        // Crear nueva persona
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
          _mostrarExito('✅ Asistencia registrada correctamente');
          Navigator.pop(context);
        } else if (mounted) {
          _mostrarError(
            '⚠️ Ya existe un registro para esta persona en el evento',
          );
        }
      } else {
        // Usar persona existente
        final res = await _service.registrarAsistenciaManual(
          _personaSeleccionada!.id,
          widget.evento.id,
          _asistio,
          _justificacionController.text.trim(),
        );

        if (res != null && mounted) {
          _mostrarExito('✅ Asistencia registrada correctamente');
          Navigator.pop(context);
        } else if (mounted) {
          _mostrarError(
            '⚠️ Ya existe un registro para esta persona en el evento',
          );
        }
      }
    } catch (e) {
      debugPrint('Error al registrar asistencia: $e');
      if (mounted) {
        _mostrarError('❌ Error al guardar. Por favor, intente nuevamente');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
