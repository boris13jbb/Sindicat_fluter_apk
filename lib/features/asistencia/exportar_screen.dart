import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../core/models/asistencia/asistencia.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

class ExportarAsistenciaScreen extends StatelessWidget {
  const ExportarAsistenciaScreen({super.key});

  static String _formatFecha(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _toCsv(List<AsistenciaConDatos> list) {
    final sb = StringBuffer();
    sb.writeln('Evento,Fecha evento,Persona,Asistió,Fecha registro,Método');
    for (final a in list) {
      sb.writeln(
        '"${a.evento.nombre}","${_formatFecha(a.evento.fecha)}","${a.persona.nombreCompleto}",${a.asistencia.asistio},"${_formatFecha(a.asistencia.fechaRegistro ?? 0)}",${a.asistencia.metodoRegistro.value}',
      );
    }
    return sb.toString();
  }

  Future<void> _exportarExcel(
    BuildContext context,
    List<AsistenciaConDatos> list,
  ) async {
    try {
      final service = AsistenciaService();
      final bytes = await service.generateExcelExport(list);

      // Guardar archivo temporal
      final directory = await getTemporaryDirectory();
      final filePath = path.join(
        directory.path,
        'asistencia_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Compartir archivo
      final result = await Share.shareXFiles([
        XFile(filePath),
      ], subject: 'Exportación de Asistencias');

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivo Excel generado y compartido')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al generar Excel: $e')));
    }
  }

  Future<void> _exportarPDF(
    BuildContext context,
    List<AsistenciaConDatos> list,
  ) async {
    try {
      final service = AsistenciaService();
      final bytes = await service.generatePDFExport(list);

      // Guardar archivo temporal
      final directory = await getTemporaryDirectory();
      final filePath = path.join(
        directory.path,
        'asistencia_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Compartir archivo
      final result = await Share.shareXFiles([
        XFile(filePath),
      ], subject: 'Reporte de Asistencias');

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF generado y compartido')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = AsistenciaService();
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Exportar Asistencias',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: FutureBuilder<List<AsistenciaConDatos>>(
        future: service.getAllAsistenciasConDatos(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
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
                      const SnackBar(
                        content: Text('Copiado al portapapeles (CSV)'),
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
                          '${a.evento.nombre} • ${_formatFecha(a.asistencia.fechaRegistro ?? 0)}',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportarExcel(context, list),
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Excel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportarPDF(context, list),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF'),
                      ),
                    ),
                  ],
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
