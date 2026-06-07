import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/models/asistencia/persona.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/asistencia_service.dart';
import '../../services/import_service.dart';
import '../elections/widgets/voto_premium_chrome.dart';

/// Pantalla premium para importación masiva de personas de asistencia.
///
/// Opcionalmente, [ModalRoute.settings.arguments] puede ser:
/// - [String]: id del documento en `eventos/{id}`
/// - [Map] con clave `'eventoId'` o `'eventId'`
class ImportarPersonasScreen extends StatefulWidget {
  const ImportarPersonasScreen({super.key});

  @override
  State<ImportarPersonasScreen> createState() => _ImportarPersonasScreenState();
}

class _ImportarPersonasScreenState extends State<ImportarPersonasScreen> {
  final _service = AsistenciaService();
  bool _cargando = false;
  String? _mensaje;
  bool _exito = false;
  int _personasImportadas = 0;
  List<String> _errores = [];

  Future<EventoAsistencia?> _eventFuture = Future.value(null);
  String? _resolvedEventRouteArg;

  static String? _parseRouteEventId(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.trim().isNotEmpty) return args.trim();
    if (args is Map) {
      final dynamic v = args['eventoId'] ?? args['eventId'] ?? args['id'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = _parseRouteEventId(context);
    if (id != _resolvedEventRouteArg) {
      _resolvedEventRouteArg = id;
      _eventFuture = id == null
          ? Future.value(null)
          : _service.getEventoById(id);
    }
  }

  /// Primera fila de plantilla típica (nombre / apellido / identificador).
  bool _looksLikePersonasHeader(List<String> row) {
    if (row.length < 3) return false;
    final h0 = row[0].toLowerCase().trim();
    final h2 = row[2].toLowerCase().trim();
    return h0.contains('nombre') ||
        h0 == 'nombres' ||
        h2.contains('ident') ||
        h2.contains('trab') ||
        h2.contains('nº') ||
        h2.contains('n°');
  }

  Future<({int importadas, int duplicadas, List<String> errores})>
  _procesarFilasPersonas(List<List<String>> filasDatos, int primeraFila) async {
    int importadas = 0;
    int duplicadas = 0;
    final errores = <String>[];

    for (var offset = 0; offset < filasDatos.length; offset++) {
      final row = filasDatos[offset];
      final i = primeraFila + offset;

      if (row.length < 3) {
        debugPrint('⚠️ Fila $i saltada: menos de 3 columnas');
        continue;
      }

      final nombres = row[0].trim();
      final apellidos = row[1].trim();
      final identificador = row[2].trim();

      if (nombres.isEmpty) {
        errores.add('Fila ${i + 1}: Nombre vacío');
        continue;
      }
      if (apellidos.isEmpty) {
        errores.add('Fila ${i + 1}: Apellido vacío');
        continue;
      }
      if (identificador.isEmpty) {
        errores.add('Fila ${i + 1}: Número de trabajador vacío');
        continue;
      }

      final personaExistente = await _service.getPersonaPorIdentificador(
        identificador,
      );

      if (personaExistente != null) {
        debugPrint('⚠️ Fila $i: Persona ya existe (ID: $identificador)');
        duplicadas++;
        continue;
      }

      final nuevaPersona = PersonaAsistencia(
        id: '',
        nombres: nombres,
        apellidos: apellidos,
        identificador: identificador,
        codigoQR: jsonEncode({
          'nombres': nombres,
          'apellidos': apellidos,
          'identificador': identificador,
        }),
      );

      await _service.createPersona(nuevaPersona);
      importadas++;
    }

    return (importadas: importadas, duplicadas: duplicadas, errores: errores);
  }

  Future<void> _importarDesdeExcel() async {
    debugPrint('🔵 [IMPORTAR] Función llamada');
    try {
      debugPrint('🔵 [IMPORTAR] Abriendo file picker...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      debugPrint(
        '🔵 [IMPORTAR] Resultado: ${result == null ? "null" : "archivo seleccionado"}',
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('⚠️ [IMPORTAR] Usuario canceló o no seleccionó archivo');
        return;
      }

      final file = result.files.first;
      debugPrint(
        '🔵 [IMPORTAR] Archivo: ${file.name}, tamaño: ${file.size} bytes',
      );
      debugPrint('🔵 [IMPORTAR] Ruta: ${file.path}');

      List<int>? fileBytes = file.bytes;

      if (fileBytes == null && file.path != null) {
        debugPrint(
          '⚠️ [IMPORTAR] file.bytes es null, intentando leer desde path...',
        );
        try {
          final fileFile = File(file.path!);
          if (await fileFile.exists()) {
            final bytes = await fileFile.readAsBytes();
            fileBytes = bytes;
            debugPrint(
              '✅ [IMPORTAR] Archivo leído correctamente: ${bytes.length} bytes',
            );
          } else {
            debugPrint(
              '❌ [IMPORTAR] El archivo no existe en la ruta especificada',
            );
          }
        } catch (e) {
          debugPrint('❌ [IMPORTAR] Error al leer archivo: $e');
        }
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        debugPrint('❌ [IMPORTAR] No se pudieron obtener los bytes del archivo');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '❌ Error: No se pudo leer el contenido del archivo. Intenta con otro archivo.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _cargando = true;
        _mensaje = null;
        _exito = false;
        _personasImportadas = 0;
        _errores = [];
      });

      final nameLower = file.name.toLowerCase();
      late final int importadas;
      late final int duplicadas;
      late final List<String> errores;

      if (nameLower.endsWith('.csv')) {
        debugPrint('🔵 [IMPORTAR] CSV: usando ImportService.parseCsv');
        final raw = ImportService.parseCsv(Uint8List.fromList(fileBytes));
        if (raw.isEmpty) {
          setState(() {
            _cargando = false;
            _mensaje = '❌ El CSV no contiene filas válidas';
            _exito = false;
          });
          return;
        }
        var startIndex = 0;
        final dataRows = <List<String>>[];
        if (_looksLikePersonasHeader(raw.first)) {
          startIndex = 1;
        }
        for (var i = startIndex; i < raw.length; i++) {
          dataRows.add(raw[i]);
        }
        if (dataRows.isEmpty) {
          setState(() {
            _cargando = false;
            _mensaje =
                '❌ No hay datos: solo encontramos encabezados o filas vacías';
            _exito = false;
          });
          return;
        }
        final r = await _procesarFilasPersonas(dataRows, startIndex);
        importadas = r.importadas;
        duplicadas = r.duplicadas;
        errores = r.errores;
      } else {
        debugPrint('🔵 [IMPORTAR] Decodificando Excel...');
        final excel = Excel.decodeBytes(fileBytes);

        if (excel.tables.isEmpty) {
          debugPrint('❌ [IMPORTAR] No hay hojas en el Excel');
          setState(() {
            _cargando = false;
            _mensaje = '❌ El archivo no contiene hojas de cálculo';
            _exito = false;
          });
          return;
        }

        debugPrint('🔵 [IMPORTAR] Hojas encontradas: ${excel.tables.keys}');

        final sheet = excel.tables.values.first;
        final dataRows = <List<String>>[];

        var startIdx = 0;
        if (sheet.rows.isNotEmpty) {
          final firstCells = sheet.rows.first
              .map((c) => c?.value?.toString().trim() ?? '')
              .toList();
          while (firstCells.isNotEmpty && firstCells.last.isEmpty) {
            firstCells.removeLast();
          }
          if (_looksLikePersonasHeader(firstCells)) {
            startIdx = 1;
          }
        }

        for (var i = startIdx; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          dataRows.add(
            row.map((c) => c?.value?.toString().trim() ?? '').toList(),
          );
        }
        if (dataRows.isEmpty) {
          setState(() {
            _cargando = false;
            _mensaje =
                '❌ No hay datos: solo encontramos encabezados o filas vacías';
            _exito = false;
          });
          return;
        }

        final r = await _procesarFilasPersonas(dataRows, startIdx);
        importadas = r.importadas;
        duplicadas = r.duplicadas;
        errores = r.errores;
      }

      String mensajeFinal;
      bool exitoFinal;

      if (importadas > 0 && duplicadas > 0) {
        mensajeFinal =
            '✅ Importación completada\n'
            '• $importadas persona(s) creada(s)\n'
            '• $duplicadas persona(s) omitida(s) (ya existían)';
        exitoFinal = true;
      } else if (importadas > 0) {
        mensajeFinal = '✅ $importadas persona(s) importada(s) exitosamente';
        exitoFinal = true;
      } else if (duplicadas > 0) {
        mensajeFinal =
            '⚠️ No se importaron personas nuevas\n'
            '• $duplicadas persona(s) ya existían en el sistema';
        exitoFinal = false;
      } else {
        mensajeFinal = '❌ No se pudo importar ninguna persona';
        exitoFinal = false;
      }

      setState(() {
        _cargando = false;
        _personasImportadas = importadas;
        _errores = errores;
        _mensaje = mensajeFinal;
        _exito = exitoFinal;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ [IMPORTAR] ERROR: $e');
      debugPrint('❌ [IMPORTAR] Stack trace: $stackTrace');
      setState(() {
        _cargando = false;
        _exito = false;
        _mensaje = '❌ Error al procesar: $e';
      });
    }
  }

  String _eventoEstadoEtiqueta(EventoAsistencia ev) =>
      ev.activo ? 'Programado' : 'Cerrado';

  String _fechaEventoFmt(EventoAsistencia ev) {
    if (ev.fecha <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ev.fecha);
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String _horaInicioFmt(EventoAsistencia ev) {
    if (ev.fecha <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ev.fecha);
    return DateFormat('HH:mm').format(dt);
  }

  Future<void> _generarDescargaPlantilla() async {
    try {
      const rows = <List<String>>[
        ['Nombres', 'Apellidos', 'N° Trabajador'],
        ['Juan Gabriel', 'Burbano Bonifaz', '37325'],
      ];
      final csv = const ListToCsvConverter(fieldDelimiter: ',').convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'plantilla_personas_asistencia.csv',
            mimeType: 'text/csv',
          ),
        ],
        subject: 'Plantilla importación personas asistencia',
        text:
            'Columnas: Nombres, Apellidos, N° Trabajador (compatible con esta app). '
            'Al importarse se crearán personas con código QR derivado.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plantilla lista para usar o enviar.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar la plantilla: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showInstruccionesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDesignTokens.background,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Formato del archivo (.xlsx, .xls o .csv)',
                  style: AppDesignTokens.titleLarge(ctx),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu archivo debe incluir:',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('• Columna A: Nombres'),
                const Text('• Columna B: Apellidos'),
                const Text('• Columna C: N° Trabajador'),
                const SizedBox(height: 12),
                Text(
                  'Al importar, se generará un QR con formato JSON:',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppDesignTokens.primaryDark.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.lavanda.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(
                      AppDesignTokens.radiusMedium,
                    ),
                    border: Border.all(
                      color: AppDesignTokens.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '{"nombres":"Juan Gabriel","apellidos":"Burbano Bonifaz","identificador":"37325"}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppDesignTokens.primaryDark.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'El QR canónico de cada socio aparece también en Mi Perfil.',
                  style: AppDesignTokens.bodyMuted(ctx),
                ),
                const SizedBox(height: 20),
                Text(
                  'Ejemplo:',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildFilaEjemplo(
                  ctx,
                  'Juan Gabriel',
                  'Burbano Bonifaz',
                  '37325',
                ),
                _buildFilaEjemplo(ctx, 'Mayra', 'Bonifaz', '21548'),
                _buildFilaEjemplo(ctx, 'Carla', 'Valenzuela', '69875'),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(
                      AppDesignTokens.radiusMedium,
                    ),
                    border: Border.all(
                      color: Colors.amber.shade200.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Importante',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• El número de trabajador debe ser único.\n'
                        '• Filas ya existentes se omitirán.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilaEjemplo(
    BuildContext context,
    String nombre,
    String apellido,
    String numero,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              apellido,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              numero,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppDesignTokens.primary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
        border: Border.all(color: const Color(0xFFE6E9EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryDark.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primaryDark.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloqueDatosPrincipal(
    BuildContext context,
    EventoAsistencia? ev,
    bool loadingEv,
  ) {
    final nombreEv = loadingEv
        ? '…'
        : (ev?.nombre.isNotEmpty == true ? ev!.nombre : '—');
    final desc = loadingEv
        ? '…'
        : ((ev?.descripcion != null && ev!.descripcion!.trim().isNotEmpty)
              ? ev.descripcion!.trim()
              : '—');
    final fecha = loadingEv ? '…' : (ev != null ? _fechaEventoFmt(ev) : '—');
    final hora = loadingEv ? '…' : (ev != null ? _horaInicioFmt(ev) : '—');
    const lugar = '—';

    final estado = loadingEv
        ? '…'
        : (ev != null ? _eventoEstadoEtiqueta(ev) : '—');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Datos principales', style: AppDesignTokens.titleLarge(context)),
        const SizedBox(height: 8),
        Text(
          ev == null && !loadingEv
              ? 'Sin evento vinculado (opcional). La importación usa el formato indicado más abajo o en el apartado Ayuda.'
              : 'Información orientativa antes de cargar datos.',
          style: AppDesignTokens.bodyMuted(context),
        ),
        const SizedBox(height: 16),
        _readOnlyRow('Nombre del evento', nombreEv),
        _readOnlyRow('Descripción', desc),
        _readOnlyRow('Fecha', fecha),
        _readOnlyRow('Hora inicio', hora),
        _readOnlyRow('Lugar', lugar),
        _readOnlyRow('Estado', estado),
        const SizedBox(height: 8),
        PrimaryButton(
          label: 'Generar descarga',
          icon: Icons.download_rounded,
          onPressed: _generarDescargaPlantilla,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cargando ? null : _importarDesdeExcel,
          child: Text(
            'Seleccionar archivo e importar',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.primary,
            ),
          ),
        ),
        if (_cargando) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppDesignTokens.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Procesando archivo…',
                style: AppDesignTokens.bodyMuted(context),
              ),
            ],
          ),
        ],
      ],
    );
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
            title: 'Importar personas',
            subtitle: 'Carga masiva',
            onBack: () => Navigator.pop(context),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VotoCircleIconButton(
                  icon: Icons.info_outline_rounded,
                  onTap: _showInstruccionesSheet,
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.upload_file_rounded,
                  onTap: _cargando ? () {} : _importarDesdeExcel,
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.download_rounded,
                  onTap: _generarDescargaPlantilla,
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<EventoAsistencia?>(
              future: _eventFuture,
              builder: (context, snapshot) {
                final loadingEv =
                    _resolvedEventRouteArg != null &&
                    snapshot.connectionState == ConnectionState.waiting;
                final eventoParaCard = loadingEv ? null : snapshot.data;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    bottom: AppDesignTokens.horizontalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -18),
                        child: PremiumCard(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: _bloqueDatosPrincipal(
                            context,
                            eventoParaCard,
                            loadingEv,
                          ),
                        ),
                      ),
                      if (_mensaje != null) ...[
                        PremiumCard(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: _bloqueResultado(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloqueResultado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _exito ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: _exito ? const Color(0xFF27AE60) : const Color(0xFFE67E22),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _mensaje!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _exito
                      ? const Color(0xFF1E8449)
                      : const Color(0xFFCA6F1E),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        if (_personasImportadas > 0 || _errores.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          if (_personasImportadas > 0)
            Text(
              '✅ $_personasImportadas persona(s) importadas',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF229954),
              ),
            ),
        ],
        if (_errores.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Errores encontrados:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._errores
              .take(10)
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (_errores.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '... y ${_errores.length - 10} errores más',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
        ],
      ],
    );
  }
}
