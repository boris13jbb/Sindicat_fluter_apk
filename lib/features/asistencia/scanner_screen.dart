import 'package:flutter/material.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

/// En web/escritorio no hay cámara; se usa un campo para pegar el código QR o barcode.
/// [evento] puede ser null si se abre desde el home; entonces se debe elegir evento en pantalla.
class ScannerAsistenciaScreen extends StatefulWidget {
  const ScannerAsistenciaScreen({super.key, this.evento});

  final EventoAsistencia? evento;

  @override
  State<ScannerAsistenciaScreen> createState() =>
      _ScannerAsistenciaScreenState();
}

class _ScannerAsistenciaScreenState extends State<ScannerAsistenciaScreen> {
  final _codigoController = TextEditingController();
  final _service = AsistenciaService();
  bool _loading = false;
  String? _mensaje;
  EventoAsistencia? _eventoSeleccionado;

  EventoAsistencia? get _evento => widget.evento ?? _eventoSeleccionado;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Registrar por código',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selector de evento
            if (widget.evento != null)
              Text(
                'Evento: ${widget.evento!.nombre}',
                style: Theme.of(context).textTheme.titleMedium,
              )
            else
              StreamBuilder<List<EventoAsistencia>>(
                stream: _service.getAllEventos(),
                builder: (context, snap) {
                  final eventos = snap.data ?? [];
                  if (eventos.isEmpty) {
                    return const Text(
                      'No hay eventos. Crea uno desde el módulo de asistencia.',
                    );
                  }
                  if (_eventoSeleccionado == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _eventoSeleccionado == null) {
                        setState(() => _eventoSeleccionado = eventos.first);
                      }
                    });
                  }
                  return DropdownButtonFormField<EventoAsistencia>(
                    initialValue: _eventoSeleccionado ?? eventos.first,
                    decoration: const InputDecoration(labelText: 'Evento'),
                    items: eventos
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.nombre)),
                        )
                        .toList(),
                    onChanged: (e) => setState(() => _eventoSeleccionado = e),
                  );
                },
              ),

            const SizedBox(height: 24),

            // Instrucciones - modo manual
            const Text(
              'Pega aquí el código escaneado (QR o código de barras), o escribe identificador/nombre,apellido,id',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),

            // Campo de texto
            TextField(
              controller: _codigoController,
              decoration: const InputDecoration(
                labelText: 'Código o identificador',
                hintText:
                    'Pega el contenido del QR o escribe: Nombre,Apellido,ID',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              onChanged: (_) => setState(() => _mensaje = null),
            ),

            if (_mensaje != null) ...[
              const SizedBox(height: 12),
              Text(
                _mensaje!,
                style: TextStyle(
                  color: _mensaje!.startsWith('Error')
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Botón de registrar
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(
                onPressed: _evento != null ? _registrar : null,
                child: Text(
                  _evento == null
                      ? 'Selecciona un evento'
                      : 'Registrar asistencia',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _registrar() async {
    final evento = _evento;
    if (evento == null) return;
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      setState(() => _mensaje = 'Escribe o pega un código');
      return;
    }
    setState(() {
      _loading = true;
      _mensaje = null;
    });
    try {
      final metodo = codigo.startsWith('{')
          ? MetodoRegistro.escaneoQr
          : MetodoRegistro.escaneoBarcode;
      final id = await _service.registrarAsistenciaDesdeEscaneo(
        codigo,
        evento.id,
        metodo,
      );
      if (!mounted) return;
      if (id != null) {
        setState(() => _mensaje = 'Asistencia registrada correctamente');
        _codigoController.clear();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(
          () => _mensaje =
              'Error: Ya estaba registrado o no se pudo crear la persona',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _mensaje = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
