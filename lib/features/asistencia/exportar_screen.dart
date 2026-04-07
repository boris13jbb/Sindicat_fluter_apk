import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'dart:async';
import '../../core/models/asistencia/asistencia.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

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
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
  return await AsistenciaService.generateExcelExportStatic(asistencias);
}

class ExportarAsistenciaScreen extends StatefulWidget {
  const ExportarAsistenciaScreen({super.key});

  @override
  State<ExportarAsistenciaScreen> createState() =>
      _ExportarAsistenciaScreenState();
}

class _ExportarAsistenciaScreenState extends State<ExportarAsistenciaScreen> {
  final AsistenciaService _service = AsistenciaService();

  Future<void> _exportarExcel(
    BuildContext context,
    List<AsistenciaConDatos> list,
  ) async {
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    // Guardar referencia al navigator
    final navigator = Navigator.of(context);

    try {
      // Serializar datos para isolate
      debugPrint('Serializando ${list.length} registros...');
      final serializedList = list.map(_serializeAsistencia).toList();

      // Mostrar loading
      final dialogContext = navigator.overlay!.context;
      showDialog(
        context: dialogContext,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          onWillPop: () async => false,
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

      // Esperar a que se muestre el diálogo
      await Future.delayed(const Duration(milliseconds: 100));

      // Generar Excel en isolate con timeout extendido
      debugPrint('Generando Excel en isolate...');
      final bytes = await compute(_generateExcelBytesIsolate, serializedList)
          .timeout(
            const Duration(seconds: 60), // Timeout extendido a 60s
            onTimeout: () {
              throw TimeoutException(
                'La generación del Excel está tardando demasiado',
              );
            },
          );

      if (!context.mounted) return;

      // Cerrar loading ANTES de compartir
      try {
        if (navigator.canPop()) {
          navigator.pop();
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        debugPrint('Error cerrando loading: $e');
      }

      // Compartir archivo usando Printing (mejor compatibilidad)
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'asistencia_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Archivo Excel generado y compartido'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error en _exportarExcel: $e');
      // Cerrar loading en caso de error
      try {
        if (navigator.canPop()) {
          navigator.pop();
        }
      } catch (e) {
        // Ignorar errores al cerrar
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error al generar Excel: ${e.toString()}')),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _exportarPDF(
    BuildContext context,
    List<AsistenciaConDatos> list,
  ) async {
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    // Mostrar loading inmediato
    if (!context.mounted) return;
    showDialog(
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
      debugPrint('Generando PDF directamente (${list.length} registros)...');

      // Generar PDF DIRECTAMENTE sin isolate (más rápido para <1000 registros)
      final bytes = await AsistenciaService.generatePDFExportStatic(list);

      if (!context.mounted) return;

      // Cerrar loading inmediatamente
      Navigator.of(context).pop();

      debugPrint('PDF generado, abriendo visor...');

      // Compartir PDF inmediatamente
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'asistencia_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('✅ PDF generado correctamente'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error al generar PDF: $e');
      // Cerrar loading si aún está abierto
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Exportar Asistencias',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: StreamBuilder<List<AsistenciaConDatos>>(
        stream: _service.watchAllAsistenciasConDatos(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error: ${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.file_download,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  const Text('No hay asistencias para exportar.'),
                ],
              ),
            );
          }
          // Serializar lista para CSV
          final serializedList = list.map(_serializeAsistencia).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${list.length} registros. Copia en formato CSV o descarga según la plataforma.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton.icon(
                  onPressed: () {
                    final csv = _toCsv(serializedList);
                    Clipboard.setData(ClipboardData(text: csv));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            const Text('Copiado al portapapeles (CSV)'),
                          ],
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar CSV al portapapeles'),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(a.persona.nombreCompleto),
                        subtitle: Text(
                          '${a.evento.nombre} • ${_formatFechaExport(a.asistencia.fechaRegistro ?? 0)}',
                        ),
                        isThreeLine: false,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 400) {
                        // Diseño vertical para pantallas pequeñas
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _exportarExcel(context, list),
                                icon: const Icon(Icons.table_chart),
                                label: const Text('Exportar Excel'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _exportarPDF(context, list),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('Exportar PDF'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Diseño horizontal para pantallas medianas/grandes
                        return Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _exportarExcel(context, list),
                                icon: const Icon(Icons.table_chart),
                                label: const Text('Excel'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _exportarPDF(context, list),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('PDF'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
