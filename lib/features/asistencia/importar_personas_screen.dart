import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../core/models/asistencia/persona.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';
import '../../services/import_service.dart';

/// Pantalla para importar personas desde Excel y generar códigos QR
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
        debugPrint(
          '⚠️ Fila $i: Persona ya existe (ID: $identificador)',
        );
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
      // Seleccionar archivo
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

      // Leer bytes manualmente si son null
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
        debugPrint('📊 Total de filas: ${sheet.rows.length}');
        if (sheet.rows.isNotEmpty) {
          debugPrint(
            '📊 Primera fila: ${sheet.rows[0].map((c) => c?.value?.toString()).toList()}',
          );
        }

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

      // Construir mensaje de resultado
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Importar personas',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instrucciones
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
                    Text(
                      '📋 Formato esperado (.xlsx, .xls o .csv)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Tu archivo ya tiene el formato correcto:',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text('• Columna A: Nombres ✅'),
                    Text('• Columna B: Apellidos ✅'),
                    Text('• Columna C: N° Trabajador ✅'),
                    SizedBox(height: 12),
                    Text(
                      'Al importar, se generarán automáticamente QRs con este formato:',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        '{"nombres":"Juan Gabriel","apellidos":"Burbano Bonifaz","identificador":"37325"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '💡 Después de importar, ve a "Códigos QR" para ver y compartir los códigos',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botón de importar
            ElevatedButton.icon(
              onPressed: _cargando ? null : _importarDesdeExcel,
              icon: _cargando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(
                _cargando ? 'Procesando...' : 'Seleccionar archivo',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Mensaje de resultado
            if (_mensaje != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _exito ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _exito
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icono y mensaje principal
                    Row(
                      children: [
                        Icon(
                          _exito
                              ? Icons.check_circle
                              : Icons.warning_amber_rounded,
                          color: _exito
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _mensaje!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _exito
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Detalles
                    if (_personasImportadas > 0 || _errores.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      if (_personasImportadas > 0)
                        Text(
                          '✅ $_personasImportadas persona(s) importadas',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                    ],
                    if (_errores.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Errores encontrados:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],

            // Ejemplo visual
            const SizedBox(height: 24),
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
                    const Text(
                      'Ejemplo de formato:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilaEjemplo(
                            context,
                            'Juan Gabriel',
                            'Burbano Bonifaz',
                            '37325',
                          ),
                          _buildFilaEjemplo(
                            context,
                            'Mayra',
                            'Bonifaz',
                            '21548',
                          ),
                          _buildFilaEjemplo(
                            context,
                            'Carla',
                            'Valenzuela',
                            '69875',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Nota importante
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Importante:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• El número de trabajador debe ser único\n'
                          '• Personas con mismo número no se duplicarán\n'
                          '• Después de importar, ve a "Códigos QR" para verlos',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
