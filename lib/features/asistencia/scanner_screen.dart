import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  String? _eventoIdSeleccionado; // Cambiado a String (ID) para evitar duplicados en Dropdown

  EventoAsistencia? get _evento {
    // Buscar evento por ID en lugar de almacenar objeto
    return widget.evento ?? 
        (_eventoIdSeleccionado != null 
            ? _getEventoFromId(_eventoIdSeleccionado!)
            : null);
  }

  // Helper para buscar evento por ID en una lista temporal
  EventoAsistencia? _getEventoFromId(String id) {
    // Este método se llamará después de cargar el stream
    return null; // Se sobrescribe con _eventoSeleccionadoObj
  }
  
  EventoAsistencia? _eventoSeleccionadoObj;
  
  EventoAsistencia? get _eventoReal => widget.evento ?? _eventoSeleccionadoObj;

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
            // Botón para escanear con cámara
            OutlinedButton.icon(
              onPressed: _iniciarEscaneo,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear código QR'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            
            // Opción manual
            Text(
              'O ingresa manualmente:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
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
                  // Seleccionar el primer evento si no hay ninguno seleccionado
                  if (_eventoIdSeleccionado == null && eventos.isNotEmpty) {
                    _eventoIdSeleccionado = eventos.first.id;
                    _eventoSeleccionadoObj = eventos.first;
                  }
                  
                  // Actualizar _eventoSeleccionadoObj si el evento seleccionado cambió
                  final currentEvento = eventos.firstWhere(
                    (e) => e.id == _eventoIdSeleccionado,
                    orElse: () => eventos.first,
                  );
                  _eventoSeleccionadoObj = currentEvento;
                  _eventoIdSeleccionado = currentEvento.id;
                  
                  return DropdownButtonFormField<String>(
                    value: _eventoIdSeleccionado,
                    decoration: const InputDecoration(labelText: 'Evento'),
                    items: eventos
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.nombre),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      setState(() {
                        _eventoIdSeleccionado = id;
                        _eventoSeleccionadoObj = eventos.firstWhere(
                          (e) => e.id == id,
                          orElse: () => eventos.first,
                        );
                      });
                    },
                  );
                },
              ),

            const SizedBox(height: 24),

            // Instrucciones - modo manual
            const Text(
              'Pega aquí el código escaneado (QR o código de barras), o escribe identificador/nombre,apellido,id',
              style: TextStyle(fontSize: 12),
            ),

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
    final evento = _eventoReal;
    if (evento == null) {
      setState(() => _mensaje = 'Selecciona un evento primero');
      return;
    }
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
        setState(() => _mensaje = '✅ Asistencia registrada correctamente');
        _codigoController.clear();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(
          () => _mensaje =
              '⚠️ Ya estaba registrado o no se pudo crear la persona',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _mensaje = '❌ Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  /// Iniciar escaneo con cámara - Modo continuo
  Future<void> _iniciarEscaneo() async {
    final evento = _eventoReal;
    if (evento == null) {
      setState(() => _mensaje = '⚠️ Selecciona un evento primero');
      return;
    }
    
    // Abrir escáner en modo continuo
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerQRScreen(
          eventoId: evento.id,
          onRegistroExitoso: (codigo) async {
            // Registrar asistencia desde el escáner continuo
            final metodo = codigo.startsWith('{')
                ? MetodoRegistro.escaneoQr
                : MetodoRegistro.escaneoBarcode;
            
            final id = await _service.registrarAsistenciaDesdeEscaneo(
              codigo,
              evento.id,
              metodo,
            );
            
            if (id == null) {
              throw Exception('Ya registrado');
            }
          },
        ),
      ),
    );
  }
}

/// Pantalla de escaneo QR con cámara - Modo continuo
class ScannerQRScreen extends StatefulWidget {
  const ScannerQRScreen({
    super.key,
    required this.eventoId,
    this.onRegistroExitoso,
  });

  final String eventoId;
  final Future<void> Function(String codigo)? onRegistroExitoso;

  @override
  State<ScannerQRScreen> createState() => _ScannerQRScreenState();
}

class _ScannerQRScreenState extends State<ScannerQRScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _escaneando = true;
  String? _ultimoCodigo;
  String? _mensaje;
  bool _exito = false;
  DateTime? _ultimoEscaneo;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
  
  /// Manejar código escaneado
  Future<void> _procesarCodigo(String codigo) async {
    if (!_escaneando) return;
    
    // Evitar escaneos duplicados muy rápidos (mínimo 2 segundos entre escaneos)
    if (_ultimoEscaneo != null &&
        DateTime.now().difference(_ultimoEscaneo!) < const Duration(seconds: 2)) {
      return;
    }
    
    setState(() {
      _escaneando = false;
      _ultimoCodigo = codigo;
      _ultimoEscaneo = DateTime.now();
    });
    
    try {
      // Registrar asistencia
      if (widget.onRegistroExitoso != null) {
        await widget.onRegistroExitoso!(codigo);
        setState(() {
          _exito = true;
          _mensaje = '✅ Registrado correctamente';
        });
      } else {
        // Si no hay callback, solo mostrar el código
        setState(() {
          _exito = true;
          _mensaje = 'Código: $codigo';
        });
      }
      
      // Auto-reset después de 1.5 segundos para permitir siguiente escaneo
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _escaneando = true;
            _mensaje = null;
            _exito = false;
            _ultimoCodigo = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _exito = false;
        _mensaje = '❌ Error: $e';
      });
      // Reset después de 3 segundos en caso de error
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _escaneando = true;
            _mensaje = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escaneo Continuo'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Cerrar escáner',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Vista de cámara
          MobileScanner(
            controller: cameraController,
            onDetect: (BarcodeCapture capture) {
              if (!_escaneando) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              
              final String? code = barcodes.first.rawValue;
              if (code != null && code.isNotEmpty) {
                _procesarCodigo(code);
              }
            },
          ),
          
          // Overlay con marco de escaneo
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _mensaje != null ? 200 : 250,
              height: _mensaje != null ? 200 : 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _mensaje != null
                      ? (_exito ? Colors.green : Colors.red)
                      : Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _mensaje != null
                    ? (_exito
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3))
                    : Colors.transparent,
              ),
            ),
          ),
          
          // Indicador de estado
          if (_mensaje != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _exito
                      ? Colors.green.withValues(alpha: 0.9)
                      : Colors.red.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _mensaje!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          // Instrucciones
          if (_mensaje == null)
            Positioned(
              bottom: 150,
              left: 0,
              right: 0,
              child: Text(
                'Apunta la cámara al código QR',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
          
          // Botón para alternar linterna
          Positioned(
            bottom: 50,
            right: 20,
            child: IconButton(
              icon: const Icon(
                Icons.flash_on,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () async {
                await cameraController.toggleTorch();
              },
            ),
          ),
          
          // Indicador de escaneos consecutivos
          Positioned(
            bottom: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Escaneo continuo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
