import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/models/asistencia/registro_asistencia_result.dart';
import '../../core/models/member.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/asistencia_service.dart';
import '../../services/asistencia_registro_api.dart';
import '../../services/attendance_service.dart';
import '../elections/widgets/voto_premium_chrome.dart';

import 'asistencia_confirmada_screen.dart';

/// Usa la cámara cuando el dispositivo y sus permisos lo permiten.
/// La entrada manual queda disponible como respaldo.
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

  Future<void> _mostrarConfirmacionPremium() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AsistenciaConfirmadaScreen(),
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
    if (widget.openScannerDirectly && puedeAbrirCamaraDirecto) {
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

  /// Resumen mostrado en la tarjeta «Última lectura» (`05_asistencia_scanner_qr`).
  String? _ultimaNombre;
  DateTime? _ultimaRegistroTime;
  bool _ultimaLecturaOk = true;

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

  void _applyUltimaLecturaExito(RegistroAsistenciaResult result) {
    if (!mounted) return;
    setState(() {
      _ultimaLecturaOk = true;
      final m = result.member;
      _ultimaNombre = m != null && m.fullName.trim().isNotEmpty
          ? m.fullName.trim()
          : 'Registrado';
      _ultimaRegistroTime = DateTime.now();
    });
  }

  String _fmtHoraRegistro(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  void _onRegistrarLectura() {
    _iniciarEscaneo();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? UserRole.user;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      bottomNavigationBar: VotoModuleBottomNavigation(
        role: role,
        selection: VotoNavSlot.asistencia,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Escáner QR',
            subtitle: 'Registro rápido de asistencia',
            onBack: () => Navigator.pop(context),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VotoCircleIconButton(
                  icon: Icons.flash_on_outlined,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'La linterna se controla durante el escaneo a pantalla completa.',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.flip_camera_android_outlined,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'El cambio de cámara está disponible en el escáner a pantalla completa.',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.sync_rounded,
                  onTap: _sincronizarMiembros,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppDesignTokens.horizontalPadding,
                12,
                AppDesignTokens.horizontalPadding,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.attendanceEventId != null)
                    _loadingMeta
                        ? const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: LinearProgressIndicator(),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Evento de asistencia',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                Text(
                                  _tituloAttendance ?? '…',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppDesignTokens.primaryDark,
                                      ),
                                ),
                              ],
                            ),
                          )
                  else if (widget.evento != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Evento: ${widget.evento!.nombre}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppDesignTokens.primaryDark,
                            ),
                      ),
                    )
                  else
                    StreamBuilder<List<EventoAsistencia>>(
                      stream: _service.getAllEventos(),
                      builder: (context, snap) {
                        final eventos = snap.data ?? [];
                        if (eventos.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'No hay eventos. Crea uno desde el módulo de asistencia.',
                            ),
                          );
                        }
                        if (_eventoIdSeleccionado == null &&
                            eventos.isNotEmpty) {
                          _eventoIdSeleccionado = eventos.first.id;
                          _eventoSeleccionadoObj = eventos.first;
                        }
                        final currentEvento = eventos.firstWhere(
                          (e) => e.id == _eventoIdSeleccionado,
                          orElse: () => eventos.first,
                        );
                        _eventoSeleccionadoObj = currentEvento;
                        _eventoIdSeleccionado = currentEvento.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: DropdownButtonFormField<String>(
                            initialValue: _eventoIdSeleccionado,
                            decoration: const InputDecoration(
                              labelText: 'Evento',
                              border: OutlineInputBorder(),
                            ),
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
                          ),
                        );
                      },
                    ),
                  PremiumCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Ubica el código QR dentro del recuadro',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppDesignTokens.primaryDark,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Validación automática de socio y evento.',
                          style: AppDesignTokens.bodyMuted(context),
                        ),
                        const SizedBox(height: 16),
                        const _ScannerViewfinderArt(),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          onPressed: (_puedeRegistrar && !_loading)
                              ? _onRegistrarLectura
                              : null,
                          label: 'Registrar lectura',
                          icon: Icons.qr_code_scanner_rounded,
                        ),
                        if (!_puedeRegistrar) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Selecciona o configura un evento de asistencia para continuar.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_ultimaNombre != null && _ultimaRegistroTime != null) ...[
                    const SizedBox(height: 16),
                    _UltimaLecturaCard(
                      nombre: _ultimaNombre!,
                      hora: _fmtHoraRegistro(_ultimaRegistroTime!),
                      ok: _ultimaLecturaOk,
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'Entrada manual',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppDesignTokens.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pega el código escaneado (QR o código de barras), o escribe identificador / Nombre,Apellido,ID.',
                    style: AppDesignTokens.bodyMuted(context),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('scanner_manual_codigo'),
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
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    PrimaryButton(
                      onPressed: _puedeRegistrar ? _registrar : null,
                      label: _puedeRegistrar
                          ? 'Registrar asistencia'
                          : 'Selecciona un evento',
                    ),
                ],
              ),
            ),
          ),
        ],
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
        _applyUltimaLecturaExito(result);
        _codigoController.clear();
        await _mostrarConfirmacionPremium();
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
            if (mounted) {
              _applyUltimaLecturaExito(result);
            }

            await _mostrarConfirmacionPremium();

            return result;
          },
        ),
      ),
    );
  }
}

/// Tarjeta de feedback «Última lectura» — layout `05_asistencia_scanner_qr`.
class _UltimaLecturaCard extends StatelessWidget {
  const _UltimaLecturaCard({
    required this.nombre,
    required this.hora,
    required this.ok,
  });

  final String nombre;
  final String hora;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final border = ok ? Colors.green.shade600 : Colors.red.shade700;
    final bg = ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final titleC = ok ? Colors.green.shade900 : Colors.red.shade900;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Última lectura',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: titleC,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$nombre • Registrado $hora',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppDesignTokens.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ok ? 'Estado: Asistencia confirmada' : 'Estado: sin confirmar',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: titleC,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ilustración del recuadro de escaneo (sin cámara en esta vista).
class _ScannerViewfinderArt extends StatefulWidget {
  const _ScannerViewfinderArt();

  @override
  State<_ScannerViewfinderArt> createState() => _ScannerViewfinderArtState();
}

class _ScannerViewfinderArtState extends State<_ScannerViewfinderArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _laser;

  @override
  void initState() {
    super.initState();
    _laser = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laser.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF0D1B2A)),
            CustomPaint(painter: _ViewfinderCornerPainter()),
            AnimatedBuilder(
              animation: _laser,
              builder: (context, _) {
                return Align(
                  alignment: Alignment(0, -1 + 2 * _laser.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [
                            AppDesignTokens.primary.withValues(alpha: 0.15),
                            AppDesignTokens.primary,
                            AppDesignTokens.primary.withValues(alpha: 0.15),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            spreadRadius: 0.5,
                            color: AppDesignTokens.primary.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const inset = 22.0;
    const len = 28.0;

    void corner(Path path) => canvas.drawPath(path, paint);

    corner(
      Path()
        ..moveTo(inset, inset + len)
        ..lineTo(inset, inset)
        ..lineTo(inset + len, inset),
    );
    corner(
      Path()
        ..moveTo(size.width - inset - len, inset)
        ..lineTo(size.width - inset, inset)
        ..lineTo(size.width - inset, inset + len),
    );
    corner(
      Path()
        ..moveTo(inset, size.height - inset - len)
        ..lineTo(inset, size.height - inset)
        ..lineTo(inset + len, size.height - inset),
    );
    corner(
      Path()
        ..moveTo(size.width - inset - len, size.height - inset)
        ..lineTo(size.width - inset, size.height - inset)
        ..lineTo(size.width - inset, size.height - inset - len),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  String _cameraErrorMessage(MobileScannerException error) {
    return switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Permiso de cámara denegado. Habilítalo en el navegador o dispositivo y vuelve a abrir el escáner.',
      MobileScannerErrorCode.unsupported =>
        'Este navegador o dispositivo no permite usar la cámara para escanear.',
      _ =>
        'No se pudo iniciar la cámara. Puedes volver e ingresar el código manualmente.',
    };
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
            errorBuilder: (context, error, child) {
              return ColoredBox(
                color: const Color(0xFF0D1B2A),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.no_photography_outlined,
                          color: Colors.white,
                          size: 52,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _cameraErrorMessage(error),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.keyboard_outlined),
                          label: const Text('Usar entrada manual'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
            child: ValueListenableBuilder<MobileScannerState>(
              valueListenable: cameraController,
              builder: (context, state, child) {
                if (!state.isInitialized ||
                    !state.isRunning ||
                    state.torchState == TorchState.unavailable) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: Icon(
                    state.torchState == TorchState.on
                        ? Icons.flash_on
                        : Icons.flash_off,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () async {
                    await cameraController.toggleTorch();
                  },
                );
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
                  const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 20,
                  ),
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
