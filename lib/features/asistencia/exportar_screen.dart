import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_branding_service.dart';
import '../../services/asistencia_service.dart';
import '../../services/attendance_service.dart';
import '../elections/widgets/voto_premium_chrome.dart';

// ============================================================================
// FUNCIONES TOP-LEVEL PARA ISOLATES (OPTIMIZADAS)
// ============================================================================

/// Serializa AsistenciaConDatos a mapa primitivo para isolate
Map<String, dynamic> _serializeAsistencia(AsistenciaConDatos a) {
  return {
    'eventoNombre': a.evento.nombre,
    'eventoFecha': a.evento.fecha,
    'personaNombre': a.persona.nombreCompleto,
    'personaIdentificador': a.persona.identificador ?? 'N/A',
    'asistio': a.asistencia.asistio,
    'metodoRegistro': a.asistencia.metodoRegistro.value,
    'fechaRegistro': a.asistencia.fechaRegistro ?? 0,
  };
}

/// Formatea fecha desde timestamp
String _formatFechaExport(int ms) {
  if (ms == 0) return 'N/A';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day}/${d.month}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Genera CSV desde lista serializable
String _toCsv(List<Map<String, dynamic>> list) {
  final sb = StringBuffer();
  sb.writeln('Evento,Fecha evento,Persona,Asistió,Fecha registro,Método');
  for (final a in list) {
    sb.writeln(
      '"${a['eventoNombre']}",'
      '"${_formatFechaExport(a['eventoFecha'] as int)}",'
      '"${a['personaNombre']}",'
      '${a['asistio'] ? 'Sí' : 'No'},'
      '"${_formatFechaExport(a['fechaRegistro'] as int)}",'
      '"${a['metodoRegistro']}"',
    );
  }
  return sb.toString();
}

/// Convierte lista serializada de vuelta a objetos AsistenciaConDatos
List<AsistenciaConDatos> _deserializeAsistencias(
  List<Map<String, dynamic>> serializedList,
) {
  return serializedList.map((map) {
    return AsistenciaConDatos(
      evento: EventoAsistencia(
        id: '',
        nombre: map['eventoNombre'] as String,
        fecha: map['eventoFecha'] as int,
        tipoReunion: TipoReunion.ordinaria,
        descripcion: '',
      ),
      persona: PersonaAsistencia(
        id: '',
        nombres: (map['personaNombre'] as String).split(' ').first,
        apellidos: (map['personaNombre'] as String)
            .split(' ')
            .skip(1)
            .join(' '),
        identificador: map['personaIdentificador'] as String?,
      ),
      asistencia: AsistenciaRegistro(
        id: '',
        eventoId: '',
        personaId: '',
        asistio: map['asistio'] as bool,
        metodoRegistro: MetodoRegistro.fromString(
          map['metodoRegistro'] as String,
        ),
        fechaRegistro: map['fechaRegistro'] as int,
      ),
    );
  }).toList();
}

/// Función top-level para generar Excel en isolate
Future<Uint8List> _generateExcelBytesIsolate(
  List<Map<String, dynamic>> serializedList,
) async {
  final asistencias = _deserializeAsistencias(serializedList);
  return AsistenciaService.generateExcelExportStatic(asistencias);
}

class ExportarAsistenciaScreen extends StatefulWidget {
  const ExportarAsistenciaScreen({super.key});

  @override
  State<ExportarAsistenciaScreen> createState() =>
      _ExportarAsistenciaScreenState();
}

enum _ExportFormat { pdf, csv, excel }

enum _OrigenExport { legacy, eventos, combinado }

extension on _ExportFormat {
  String get label {
    switch (this) {
      case _ExportFormat.pdf:
        return 'PDF';
      case _ExportFormat.csv:
        return 'CSV';
      case _ExportFormat.excel:
        return 'Excel';
    }
  }
}

class _ExportarAsistenciaScreenState extends State<ExportarAsistenciaScreen> {
  final AsistenciaService _service = AsistenciaService();
  final AttendanceService _attendance = AttendanceService();

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  StreamSubscription<List<AttendanceEvent>>? _eventsSub;
  List<AttendanceEvent> _eventsCatalog = [];

  _ExportFormat _formato = _ExportFormat.pdf;
  _OrigenExport _origen = _OrigenExport.combinado;

  DateTime _desde = DateTime.now();
  DateTime _hasta = DateTime.now();

  /// `null` = todos los eventos del catálogo [attendance_events].
  String? _eventoSeleccionadoId;

  bool _loadingGenerate = false;

  List<AttendanceEvent> _sortedEventsForDropdown() =>
      [..._eventsCatalog]..sort((a, b) => b.fecha.compareTo(a.fecha));

  @override
  void initState() {
    super.initState();
    _eventsSub = _attendance.getAllEvents().listen((list) {
      if (!mounted) return;
      setState(() => _eventsCatalog = list);
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  int _startOfDayMs(DateTime d) =>
      DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  int _endOfDayMs(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999).millisecondsSinceEpoch;

  bool _matchesEvent(AsistenciaConDatos a, String? eventId) {
    if (eventId == null) return true;
    return a.evento.id == eventId || a.asistencia.eventoId == eventId;
  }

  bool _matchesDate(AsistenciaConDatos a, int startMs, int endMs) {
    final fr = a.asistencia.fechaRegistro;
    if (fr != null && fr > 0) {
      return fr >= startMs && fr <= endMs;
    }
    final ev = a.evento.fecha;
    return ev >= startMs && ev <= endMs;
  }

  Future<List<AsistenciaConDatos>> _fetchFilteredRows() async {
    final startMs = _startOfDayMs(_desde);
    final endMs = _endOfDayMs(_hasta);

    late List<AsistenciaConDatos> base;
    switch (_origen) {
      case _OrigenExport.legacy:
        base = await _service.getAllAsistenciasConDatos();
        break;
      case _OrigenExport.eventos:
        base = await _attendance.fetchAllAttendanceExportsRows();
        break;
      case _OrigenExport.combinado:
        final legacy = await _service.getAllAsistenciasConDatos();
        final nuevo = await _attendance.fetchAllAttendanceExportsRows();
        base = [...legacy, ...nuevo];
        base.sort((a, b) {
          final ta = a.asistencia.fechaRegistro ?? 0;
          final tb = b.asistencia.fechaRegistro ?? 0;
          return tb.compareTo(ta);
        });
        break;
    }

    return base.where((a) {
      return _matchesEvent(a, _eventoSeleccionadoId) &&
          _matchesDate(a, startMs, endMs);
    }).toList();
  }

  String _tipoReporteEtiqueta() {
    switch (_origen) {
      case _OrigenExport.combinado:
        return 'Completo';
      case _OrigenExport.eventos:
        return 'Eventos actuales';
      case _OrigenExport.legacy:
        return 'Histórico';
    }
  }

  String _eventoEtiqueta() {
    if (_eventoSeleccionadoId == null) return 'Todos los eventos';
    for (final e in _eventsCatalog) {
      if (e.id == _eventoSeleccionadoId) return e.nombre;
    }
    return 'Evento (${_eventoSeleccionadoId!})';
  }

  Widget _premiumSelect<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      // ignore: deprecated_member_use — controlado desde el State; mismo patrón que el resto del proyecto
      value: value,
      decoration: votoPremiumInputDecoration(label),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _fechaField({
    required String label,
    required DateTime fecha,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _loadingGenerate ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: votoPremiumInputDecoration(label),
        child: Text(
          _dateFmt.format(fecha),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppDesignTokens.primaryDark,
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmarExportacion({
    required String formato,
    required int registros,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Exportar $formato'),
            content: Text(
              'Se exportarán $registros registro(s) de asistencia según filtros '
              'seleccionados. El archivo puede incluir nombres, eventos, horarios '
              'y estado de asistencia. Compártelo sólo con personal autorizado.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Continuar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _exportarCsv(List<AsistenciaConDatos> list) async {
    final serializedList = list.map(_serializeAsistencia).toList();
    final csv = _toCsv(serializedList);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'asistencias_$timestamp.csv';
    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(utf8.encode('\uFEFF$csv')),
        name: fileName,
        mimeType: 'text/csv',
      ),
    ], subject: 'Reporte de asistencias');
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV listo (${list.length} registros)'),
        backgroundColor: scheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportarExcel(List<AsistenciaConDatos> list) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    debugPrint('Serializando ${list.length} registros...');
    final serializedList = list.map(_serializeAsistencia).toList();

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Generando Excel...'),
                  const SizedBox(height: 8),
                  Text(
                    'Procesando ${list.length} registros...',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      final bytes = await compute(_generateExcelBytesIsolate, serializedList)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException(
              'La generación del Excel está tardando demasiado',
            ),
          );

      if (!mounted) return;
      try {
        if (navigator.canPop()) navigator.pop();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } catch (_) {}

      final fileName =
          'asistencias_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          name: fileName,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ], subject: 'Exportación Excel asistencias');

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Excel listo para compartir'),
            ],
          ),
          backgroundColor: scheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error en Excel: $e');
      if (navigator.canPop()) navigator.pop();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al generar Excel: $e'),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportarPdf(List<AsistenciaConDatos> list) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generando PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final branding = await AppBrandingService().getReportBrandingOnce();
      final logoBytes = await AppBrandingService.loadReportLogoBytes(
        branding?.reportLogoUrl,
      );
      final bytes = await AsistenciaService.generatePDFExportStatic(
        list,
        reportLogoBytes: logoBytes,
      );
      if (!mounted) return;
      Navigator.of(context).pop();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'asistencias_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('PDF listo para compartir'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error PDF: $e');
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo generar PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _generarDescarga() async {
    if (_loadingGenerate) return;
    if (_desde.isAfter(_hasta)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('«Desde» no puede ser posterior a «Hasta»'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_eventoSeleccionadoId != null &&
        !_eventsCatalog.any((e) => e.id == _eventoSeleccionadoId)) {
      setState(() => _eventoSeleccionadoId = null);
    }

    setState(() => _loadingGenerate = true);
    List<AsistenciaConDatos>? filtered;
    try {
      filtered = await _fetchFilteredRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
      }
      filtered = null;
    } finally {
      if (mounted) setState(() => _loadingGenerate = false);
    }

    final list = filtered;
    if (list == null || !mounted) return;

    if (list.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _eventoSeleccionadoId != null
                ? 'No hay registros en el rango y evento seleccionados.'
                : 'No hay registros con los filtros actuales.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await _confirmarExportacion(
      formato: _formato.label,
      registros: list.length,
    );
    if (!ok || !mounted) return;

    switch (_formato) {
      case _ExportFormat.pdf:
        await _exportarPdf(list);
        break;
      case _ExportFormat.csv:
        await _exportarCsv(list);
        break;
      case _ExportFormat.excel:
        await _exportarExcel(list);
        break;
    }
  }

  Future<void> _pickDesde() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _desde,
      firstDate: DateTime(2018),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _desde = picked;
      if (_desde.isAfter(_hasta)) _hasta = _desde;
    });
  }

  Future<void> _pickHasta() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hasta,
      firstDate: DateTime(2018),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _hasta = picked;
      if (_hasta.isBefore(_desde)) _desde = _hasta;
    });
  }

  void _setHoyAmbasFechas() {
    final h = DateTime.now();
    setState(() {
      _desde = DateTime(h.year, h.month, h.day);
      _hasta = DateTime(h.year, h.month, h.day);
    });
  }

  void _showInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtros de exportación',
                    style: AppDesignTokens.titleLarge(ctx),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tipo de reporte: «Completo» une histórico (modelo anterior) '
                    'y registros del flujo actual (attendance_events). «Histórico» '
                    'y «Eventos actuales» usan sólo ese origen.\n\n'
                    'Las fechas filtran por fecha de registro cuando existe; '
                    'si no, por fecha del evento asociado.\n\n'
                    'El selector de evento aplica sólo sobre documentos '
                    'cuyo ID de evento coincida.',
                    style: AppDesignTokens.bodyMuted(ctx),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? UserRole.user;

    final eventItems = [
      DropdownMenuItem<String?>(
        value: null,
        child: Text('Todos los eventos', overflow: TextOverflow.ellipsis),
      ),
      ..._sortedEventsForDropdown().map((e) {
        return DropdownMenuItem<String?>(
          value: e.id,
          child: Text(e.nombre, overflow: TextOverflow.ellipsis),
        );
      }),
    ];

    final eventValue =
        (_eventoSeleccionadoId != null &&
            _eventsCatalog.any((e) => e.id == _eventoSeleccionadoId))
        ? _eventoSeleccionadoId
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: VotoModuleBottomNavigation(
        role: role,
        selection: VotoNavSlot.asistencia,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Exportar reportes',
            subtitle: 'PDF, CSV y Excel',
            onBack: () => Navigator.maybePop(context),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VotoCircleIconButton(
                  icon: Icons.today_rounded,
                  onTap: _setHoyAmbasFechas,
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.info_outline_rounded,
                  onTap: _showInfoSheet,
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    _eventsSub?.cancel();
                    _eventsSub = _attendance.getAllEvents().listen((list) {
                      if (!mounted) return;
                      setState(() => _eventsCatalog = list);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Suscripción de eventos reiniciada'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppDesignTokens.horizontalPadding,
                8,
                AppDesignTokens.horizontalPadding,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PremiumCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Datos principales',
                          style: AppDesignTokens.titleLarge(context),
                        ),
                        const SizedBox(height: 18),
                        _premiumSelect<_ExportFormat>(
                          label: 'Formato',
                          value: _formato,
                          items: [
                            DropdownMenuItem(
                              value: _ExportFormat.pdf,
                              child: const Text('PDF'),
                            ),
                            DropdownMenuItem(
                              value: _ExportFormat.csv,
                              child: const Text('CSV'),
                            ),
                            DropdownMenuItem(
                              value: _ExportFormat.excel,
                              child: const Text('Excel'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _formato = v);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String?>(
                          // ignore: deprecated_member_use — controlado desde el State; mismo patrón que el resto del proyecto
                          value: eventValue,
                          decoration: votoPremiumInputDecoration('Evento'),
                          items: eventItems,
                          onChanged: _loadingGenerate
                              ? null
                              : (v) =>
                                    setState(() => _eventoSeleccionadoId = v),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _fechaField(
                                label: 'Desde',
                                fecha: _desde,
                                onTap: _pickDesde,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _fechaField(
                                label: 'Hasta',
                                fecha: _hasta,
                                onTap: _pickHasta,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _premiumSelect<_OrigenExport>(
                          label: 'Tipo de reporte',
                          value: _origen,
                          items: const [
                            DropdownMenuItem(
                              value: _OrigenExport.combinado,
                              child: Text('Completo'),
                            ),
                            DropdownMenuItem(
                              value: _OrigenExport.eventos,
                              child: Text('Eventos actuales'),
                            ),
                            DropdownMenuItem(
                              value: _OrigenExport.legacy,
                              child: Text('Histórico'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _origen = v);
                          },
                        ),
                        const SizedBox(height: 22),
                        PrimaryButton(
                          label: 'Generar descarga',
                          isLoading: _loadingGenerate,
                          onPressed: _generarDescarga,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Selección actual: ${_formato.label} • '
                      '${_tipoReporteEtiqueta()} • '
                      '${_eventoEtiqueta()} (${_dateFmt.format(_desde)} – ${_dateFmt.format(_hasta)})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
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
