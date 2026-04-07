import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:convert';
import 'dart:io';
import '../../core/models/asistencia/persona.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

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

  Future<void> _importarDesdeExcel() async {
    debugPrint('🔵 [IMPORTAR] Función llamada');
    try {
      // Seleccionar archivo
      debugPrint('🔵 [IMPORTAR] Abriendo file picker...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      debugPrint('🔵 [IMPORTAR] Resultado: ${result == null ? "null" : "archivo seleccionado"}');
      
      if (result == null || result.files.isEmpty) {
        debugPrint('⚠️ [IMPORTAR] Usuario canceló o no seleccionó archivo');
        return;
      }

      final file = result.files.first;
      debugPrint('🔵 [IMPORTAR] Archivo: ${file.name}, tamaño: ${file.size} bytes');
      debugPrint('🔵 [IMPORTAR] Ruta: ${file.path}');
      
      // Leer bytes manualmente si son null
      List<int>? fileBytes = file.bytes;
      
      if (fileBytes == null && file.path != null) {
        debugPrint('⚠️ [IMPORTAR] file.bytes es null, intentando leer desde path...');
        try {
          final fileFile = File(file.path!);
          if (await fileFile.exists()) {
            fileBytes = await fileFile.readAsBytes();
            debugPrint('✅ [IMPORTAR] Archivo leído correctamente: ${fileBytes!.length} bytes');
          } else {
            debugPrint('❌ [IMPORTAR] El archivo no existe en la ruta especificada');
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
              content: Text('❌ Error: No se pudo leer el contenido del archivo. Intenta con otro archivo.'),
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

      debugPrint('🔵 [IMPORTAR] Decodificando Excel...');
      // Procesar archivo
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

      // Obtener primera hoja
      final sheet = excel.tables.values.first;
      int importadas = 0;
      int duplicadas = 0;
      final errores = <String>[];

      // Debug: Mostrar estructura del Excel
      debugPrint('📊 Total de filas: ${sheet.rows.length}');
      if (sheet.rows.isNotEmpty) {
        debugPrint('📊 Primera fila: ${sheet.rows[0].map((c) => c?.value?.toString()).toList()}');
      }

      // Recorrer filas (empezando desde fila 0)
      for (var i = 0; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        
        // Debug: Ver cada fila
        debugPrint('📝 Fila $i: ${row.length} columnas');
        for (var j = 0; j < row.length && j < 3; j++) {
          debugPrint('   Columna $j: "${row[j]?.value?.toString()}"');
        }
        
        // Si hay menos de 3 columnas, saltar (necesitamos: nombre, apellido, identificador)
        if (row.length < 3) {
          debugPrint('⚠️ Fila $i saltada: menos de 3 columnas');
          continue;
        }

        // Obtener valores de cada columna
        final cell0 = row[0];
        final cell1 = row[1];
        final cell2 = row[2];
        
        // Extraer texto correctamente
        String? nombres;
        String? apellidos;
        String? identificador;
        
        // Manejar diferentes tipos de celdas
        if (cell0 != null) {
          nombres = cell0.value?.toString().trim();
        }
        if (cell1 != null) {
          apellidos = cell1.value?.toString().trim();
        }
        if (cell2 != null) {
          identificador = cell2.value?.toString().trim();
        }

        // Debug: Mostrar datos extraídos
        debugPrint('📋 Datos extraídos Fila $i:');
        debugPrint('   Nombres: "$nombres"');
        debugPrint('   Apellidos: "$apellidos"');
        debugPrint('   Identificador: "$identificador"');

        // Validar datos
        if (nombres == null || nombres.isEmpty) {
          errores.add('Fila ${i + 1}: Nombre vacío');
          debugPrint('❌ Error Fila $i: Nombre vacío');
          continue;
        }
        if (apellidos == null || apellidos.isEmpty) {
          errores.add('Fila ${i + 1}: Apellido vacío');
          debugPrint('❌ Error Fila $i: Apellido vacío');
          continue;
        }
        if (identificador == null || identificador.isEmpty) {
          errores.add('Fila ${i + 1}: Número de trabajador vacío');
          debugPrint('❌ Error Fila $i: Identificador vacío');
          continue;
        }

        // Verificar si ya existe persona con ese identificador
        final personaExistente = await _service.getPersonaPorIdentificador(identificador);
        
        if (personaExistente != null) {
          debugPrint('⚠️ Fila $i: Persona ya existe (ID: $identificador)');
          duplicadas++;
          continue;
        }

        // Crear nueva persona
        debugPrint('✅ Creando persona: $nombres $apellidos ($identificador)');
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

      // Construir mensaje de resultado
      String mensajeFinal;
      bool exitoFinal;

      if (importadas > 0 && duplicadas > 0) {
        mensajeFinal = '✅ Importación completada\n'
            '• $importadas persona(s) creada(s)\n'
            '• $duplicadas persona(s) omitida(s) (ya existían)';
        exitoFinal = true;
      } else if (importadas > 0) {
        mensajeFinal = '✅ $importadas persona(s) importada(s) exitosamente';
        exitoFinal = true;
      } else if (duplicadas > 0) {
        mensajeFinal = '⚠️ No se importaron personas nuevas\n'
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
        title: 'Importar desde Excel',
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
                      '📋 IMPORTANTE: Tu Excel está perfecto!',
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
                      style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
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
                _cargando ? 'Procesando...' : 'Seleccionar archivo Excel',
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
                  color: _exito
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _exito ? Colors.green.shade200 : Colors.orange.shade200,
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
                          _exito ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: _exito ? Colors.green.shade700 : Colors.orange.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _mensaje!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _exito ? Colors.green.shade800 : Colors.orange.shade800,
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
                      ..._errores.take(10).map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
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
                          _buildFilaEjemplo(context, 'Juan Gabriel', 'Burbano Bonifaz', '37325'),
                          _buildFilaEjemplo(context, 'Mayra', 'Bonifaz', '21548'),
                          _buildFilaEjemplo(context, 'Carla', 'Valenzuela', '69875'),
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

  Widget _buildEjemploColumna(BuildContext context, String columna, String descripcion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              columna,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            descripcion,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFilaEjemplo(BuildContext context, String nombre, String apellido, String numero) {
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
