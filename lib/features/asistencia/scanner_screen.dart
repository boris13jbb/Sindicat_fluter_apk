import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/models/asistencia/registro_asistencia_result.dart';
import '../../core/models/member.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';
import '../../services/asistencia_registro_api.dart';
import '../../services/attendance_service.dart';

/// En web/escritorio no hay cámara; se usa un campo para pegar el código QR o barcode.
/// [evento] puede ser null si se abre desde el home; entonces se debe elegir evento en pantalla.
class ScannerAsistenciaScreen extends StatefulWidget {
  const ScannerAsistenciaScreen({
    super.key,
    this.evento,
    this.attendanceEventId,
    this.service,
    this.openScannerDirectly = false,
  });

  /// Evento colección **`eventos`** (legacy).
  final EventoAsistencia? evento;

  /// Doc en **`attendance_events`** cuando el registro va al modelo actual.
  final String? attendanceEventId;

  /// Abre de inmediato [ScannerQRScreen] (desde FAB de detalle de evento).
  final bool openScannerDirectly;

  /// Inyección opcional para pruebas.
  final AsistenciaRegistroApi? service;

  @override
  State<ScannerAsistenciaScreen> createState() =>
      _ScannerAsistenciaScreenState();
}

class _ScannerAsistenciaScreenState extends State<ScannerAsistenciaScreen> {
  final _codigoController = TextEditingController();
  late final AsistenciaRegistroApi _service;
  bool _loading = false;
  bool _autoEscaneoLanzado = false;
  String? _mensaje;
  String?
  _eventoIdSeleccionado; // Cambiado a String (ID) para evitar duplicados en Dropdown

  String _etiquetaModalidad(Member? member) {
    final mod = member?.modalidad;
    if (mod == null) {
      return 'Sin asignar — un administrador debe actualizarla en Gestión de Socios';
    }
    return JustificacionHelper.etiquetaModalidad(mod);
  }

  String _detallesSocio(Member? member) {
    if (member == null) return 'Socio no encontrado en el padrón (members).';

    final buffer = StringBuffer()
      ..writeln('Nombre: ${member.fullName}')
      ..writeln('Código trabajador: ${member.workerCode ?? "-"}')
      ..writeln('Cédula: ${member.documentId ?? "-"}')
      ..writeln('Modalidad: ${_etiquetaModalidad(member)}');

    return buffer.toString().trimRight();
  }

  Future<void> _mostrarResultadoRegistro({
    required String titulo,
    required String mensaje,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(child: Text(mensaje)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AsistenciaService();
    _sincronizarMiembros();
    if (widget.attendanceEventId != null) _cargarMetaAttendance();
    final puedeAbrirCamaraDirecto =
        (widget.attendanceEventId != null &&
            widget.attendanceEventId!.isNotEmpty) ||
        widget.evento != null;
    if (!kIsWeb && widget.openScannerDirectly && puedeAbrirCamaraDirecto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoEscaneoLanzado) return;
        _autoEscaneoLanzado = true;
        _iniciarEscaneo();
      });
    }
  }

  Future<void> _sincronizarMiembros() async {
    try {
      debugPrint(
        '🔄 Ejecutando sincronización members → personas desde scanner...',
      );
      final resultado = await _service.sincronizarMiembrosConPersonas();
      debugPrint('✅ Sincronización completada: $resultado');

      if (mounted) {
        final total = resultado['total_procesados'] ?? 0;
        final sincronizados = resultado['sincronizados'] ?? 0;

        if (sincronizados > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Se sincronizaron $sincronizados de $total miembros',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error en sincronización: $e');
    }
  }

  EventoAsistencia? _eventoSeleccionadoObj;

  EventoAsistencia? get _eventoLegacy =>
      widget.evento ?? _eventoSeleccionadoObj;

  String? _tituloAttendance;
  bool _loadingMeta = false;

  bool get _puedeRegistrar =>
      widget.attendanceEventId != null || _eventoLegacy != null;

  Future<void> _cargarMetaAttendance() async {
    final id = widget.attendanceEventId;
    if (id == null || id.isEmpty) return;
    setState(() {
      _loadingMeta = true;
      _tituloAttendance = null;
    });
    try {
      final ev = await AttendanceService().getEventById(id);
      if (!mounted) return;
      setState(() {
        _tituloAttendance = ev?.nombre ?? '(evento)';
        _loadingMeta = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            // Selector de evento / contexto
            if (widget.attendanceEventId != null)
              _loadingMeta
                  ? const LinearProgressIndicator()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evento de asistencia',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          _tituloAttendance ?? '…',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    )
            else if (widget.evento != null)
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
                    initialValue: _eventoIdSeleccionado,
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
                onPressed: _puedeRegistrar ? _registrar : null,
                child: Text(
                  _puedeRegistrar
                      ? 'Registrar asistencia'
                      : 'Selecciona un evento',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _registrar() async {
    final leg = _eventoLegacy;
    final attId = widget.attendanceEventId;
    final eventoFirestoreId = attId ?? leg?.id;
    if (eventoFirestoreId == null || eventoFirestoreId.isEmpty) {
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
      final result = await _service.registrarAsistenciaDesdeEscaneo(
        codigo,
        eventoFirestoreId,
        metodo,
        registrosAttendanceEvents: attId != null,
      );
      if (!mounted) return;
      if (result.ok) {
        _codigoController.clear();
        await _mostrarResultadoRegistro(
          titulo: '✅ Asistencia registrada',
          mensaje: _detallesSocio(result.member),
        );
        if (mounted) Navigator.pop(context);
      } else {
        setState(
          () => _mensaje = attId != null
              ? '⚠️ Ya está registrado o el QR no coincide con socio en `members`.'
              : '⚠️ Ya estaba registrado o no se pudo crear la persona',
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
    final leg = _eventoLegacy;
    final attId = widget.attendanceEventId;
    final eventoFirestoreId = attId ?? leg?.id;
    if (eventoFirestoreId == null || eventoFirestoreId.isEmpty) {
      setState(() => _mensaje = '⚠️ Selecciona un evento primero');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerQRScreen(
          eventId: eventoFirestoreId,
          registrosAttendanceEvents: attId != null,
          onRegistroExitoso: (codigo) async {
            final metodo = codigo.startsWith('{')
                ? MetodoRegistro.escaneoQr
                : MetodoRegistro.escaneoBarcode;

            final result = await _service.registrarAsistenciaDesdeEscaneo(
              codigo,
              eventoFirestoreId,
              metodo,
              registrosAttendanceEvents: attId != null,
            );

            if (!result.ok) {
              throw Exception('Ya registrado');
            }

            await _mostrarResultadoRegistro(
              titulo: '✅ Asistencia registrada',
              mensaje: _detallesSocio(result.member),
            );

            return result;
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
    required this.eventId,
    this.registrosAttendanceEvents = false,
    this.onRegistroExitoso,
  });

  final String eventId;
  final bool registrosAttendanceEvents;
  final Future<RegistroAsistenciaResult> Function(String codigo)?
  onRegistroExitoso;

  @override
  State<ScannerQRScreen> createState() => _ScannerQRScreenState();
}

class _ScannerQRScreenState extends State<ScannerQRScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _escaneando = true;
  String? _mensaje;
  bool _exito = false;
  DateTime? _ultimoEscaneo;

  String _etiquetaModalidad(Member? member) {
    final mod = member?.modalidad;
    if (mod == null) return 'Sin asignar';
    return JustificacionHelper.etiquetaModalidad(mod);
  }

  String _overlayDetalle(Member? member) {
    if (member == null) return 'Socio no encontrado en padrón';
    final worker = member.workerCode?.isNotEmpty == true
        ? member.workerCode!
        : '-';
    final doc = member.documentId?.isNotEmpty == true
        ? member.documentId!
        : '-';
    return [
      member.fullName,
      'Modalidad: ${_etiquetaModalidad(member)}',
      'Trabajador: $worker',
      'Cédula: $doc',
    ].join('\n');
  }

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
        DateTime.now().difference(_ultimoEscaneo!) <
            const Duration(seconds: 2)) {
      return;
    }

    setState(() {
      _escaneando = false;
      _ultimoEscaneo = DateTime.now();
    });

    try {
      // Registrar asistencia
      if (widget.onRegistroExitoso != null) {
        final result = await widget.onRegistroExitoso!(codigo);
        setState(() {
          _exito = result.ok;
          _mensaje = result.ok
              ? _overlayDetalle(result.member)
              : '⚠️ Ya registrado';
        });
      } else {
        // Si no hay callback, solo mostrar el código
        setState(() {
          _exito = true;
          _mensaje = 'Código: $codigo';
        });
      }

      // Auto-reset después de 2.5s para permitir validar nombre/modalidad
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _escaneando = true;
            _mensaje = null;
            _exito = false;
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
              icon: const Icon(Icons.flash_on, color: Colors.white, size: 32),
              onPressed: () async {
                await cameraController.toggleTorch();
              },
            ),
          ),

          // Indicador de escaneos consecutivos
          Positioned(
            bottom: 50,
            left: 20,
            right: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Escaneo continuo',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
