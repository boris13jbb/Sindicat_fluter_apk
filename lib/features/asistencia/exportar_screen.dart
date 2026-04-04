import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import '../../core/models/asistencia/asistencia.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

String _formatFechaExport(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _toCsv(List<AsistenciaConDatos> list) {
  final sb = StringBuffer();
  sb.writeln('Evento,Fecha evento,Persona,Asistió,Fecha registro,Método');
  for (final a in list) {
    sb.writeln(
      '"${a.evento.nombre}","${_formatFechaExport(a.evento.fecha)}","${a.persona.nombreCompleto}",${a.asistencia.asistio},"${_formatFechaExport(a.asistencia.fechaRegistro ?? 0)}",${a.asistencia.metodoRegistro.value}',
    );
  }
  return sb.toString();
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

    try {
      // Los datos ya vienen validados por el modelo AsistenciaConDatos
      final validList = list;

      if (validList.isEmpty) {
        throw Exception('Los datos de asistencia están incompletos');
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
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
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Generar Excel en segundo plano con timeout
      final bytes = await compute(_generateExcelBytes, validList).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'La generación del Excel está tardando demasiado',
          );
        },
      );

      if (!context.mounted) return;

      final directory = await getTemporaryDirectory();
      final filePath = path.join(
        directory.path,
        'asistencia_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([
        XFile(filePath),
      ], subject: 'Exportación de Asistencias');

      if (!context.mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Cerrar loading
      }

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
      if (!context.mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
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

    try {
      debugPrint('Generando reporte profesional de PDF de asistencia...');

      // Los datos ya vienen validados por el modelo AsistenciaConDatos
      final validList = list;

      if (validList.isEmpty) {
        throw Exception('Los datos de asistencia están incompletos');
      }

      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Generando PDF...'),
                  const SizedBox(height: 8),
                  Text(
                    'Procesando ${list.length} registros...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Generar PDF en segundo plano con timeout
      final bytes = await compute(_generateAttendancePdf, validList).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'La generación del PDF está tardando demasiado',
          );
        },
      );

      if (!context.mounted) return;

      // Usar Printing.sharePdf para mejor compatibilidad
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'asistencia_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      if (!context.mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Cerrar loading
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✅ PDF Generado',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Reporte de asistencias exportado correctamente',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error al generar PDF: $e');
      if (!context.mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '❌ Error al Generar PDF',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'No se pudo generar el reporte. Intente nuevamente.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Funciones top-level para compute (aislamiento)
  Future<Uint8List> _generateExcelBytes(List<AsistenciaConDatos> list) async {
    return await AsistenciaService.generateExcelExportStatic(list);
  }

  Future<Uint8List> _generateAttendancePdf(
    List<AsistenciaConDatos> list,
  ) async {
    return await AsistenciaService.generatePDFExportStatic(list);
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
                    final csv = _toCsv(list);
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
