import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/asistencia/evento.dart';
import '../models/asistencia/asistencia.dart';

/// Generador profesional de reportes PDF para asistencias a eventos.
class AttendanceReportGenerator {
  AttendanceReportGenerator({required this.asistencias, this.evento});

  final List<AsistenciaConDatos> asistencias;
  final EventoAsistencia? evento;

  // Campos para estadísticas precalculadas
  late final int _totalAsistencias;
  late final int _asistieron;
  late final int _noAsistieron;
  late final double _porcentajeAsistencia;

  // Colores corporativos
  static final _primaryColor = PdfColor.fromInt(0xFF6750A4);
  static final _secondaryColor = PdfColor.fromInt(0xFF625B71);
  static final _successColor = PdfColor.fromInt(0xFF4CAF50);
  static final _lightGray = PdfColor.fromInt(0xFFF5F5F5);
  static final _mediumGray = PdfColor.fromInt(0xFFE0E0E0);

  /// Genera el PDF completo
  Future<Uint8List> generateReport() async {
    try {
      // Validar datos de entrada
      if (asistencias.isEmpty) {
        throw Exception('No hay datos de asistencias para generar el reporte');
      }

      // Los datos ya vienen validados por el modelo AsistenciaConDatos
      final validAsistencias = asistencias;

      if (validAsistencias.isEmpty) {
        throw Exception('No hay asistencias válidas con datos completos');
      }

      // Precalcular estadísticas
      _totalAsistencias = validAsistencias.length;
      _asistieron = validAsistencias.where((a) => a.asistencia.asistio).length;
      _noAsistieron = _totalAsistencias - _asistieron;
      _porcentajeAsistencia = _totalAsistencias > 0
          ? ((_asistieron / _totalAsistencias) * 100)
          : 0.0;

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            _buildHeader(),
            pw.SizedBox(height: 24),
            _buildEventInfo(),
            pw.SizedBox(height: 24),
            _buildSummary(),
            pw.SizedBox(height: 24),
            _buildAttendanceTable(),
            pw.SizedBox(height: 30),
            _buildFooter(),
          ],
        ),
      );

      return await pdf.save();
    } catch (e, stackTrace) {
      debugPrint('❌ Error generando reporte PDF: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Encabezado del reporte
  pw.Widget _buildHeader() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.all(32),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'REPORTE DE ASISTENCIA',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
          if (evento != null) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              evento!.nombre,
              style: pw.TextStyle(
                fontSize: 16,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Información del evento
  pw.Widget _buildEventInfo() {
    if (evento == null) {
      return pw.Container();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'INFORMACIÓN DEL EVENTO',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.SizedBox(height: 12),
        _buildInfoRow('Nombre:', evento!.nombre),
        _buildInfoRow('Fecha:', _formatDate(evento!.fecha)),
        _buildInfoRow('Tipo:', _formatTipoReunion(evento!.tipoReunion.value)),
        if (evento!.descripcion != null && evento!.descripcion!.isNotEmpty)
          _buildInfoRow('Descripción:', evento!.descripcion!),
      ],
    );
  }

  /// Resumen estadístico
  pw.Widget _buildSummary() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RESUMEN DE ASISTENCIA',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildStatCard('Total Registros', '$_totalAsistencias', '📋'),
            pw.SizedBox(width: 16),
            _buildStatCard(
              'Asistieron',
              '$_asistieron',
              '✅',
              color: _successColor,
            ),
            pw.SizedBox(width: 16),
            _buildStatCard('No Asistieron', '$_noAsistieron', '❌'),
            pw.SizedBox(width: 16),
            _buildStatCard(
              'Porcentaje',
              '${_porcentajeAsistencia.toStringAsFixed(1)}%',
              '📊',
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        _buildBarChart(),
      ],
    );
  }

  /// Tabla de asistencias detallada
  pw.Widget _buildAttendanceTable() {
    final tableRows = <pw.TableRow>[];

    // Encabezados
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _primaryColor),
        children: [
          _buildHeaderCell('Persona'),
          _buildHeaderCell('Identificador'),
          _buildHeaderCell('Asistió'),
          _buildHeaderCell('Método'),
          _buildHeaderCell('Fecha Registro'),
        ],
      ),
    );

    // Datos - optimizado
    for (final a in asistencias) {
      tableRows.add(_buildAttendanceRow(a));
    }

    // Total
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _mediumGray),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              'TOTAL',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.SizedBox(),
          _buildTotalCell('${asistencias.length}'),
          pw.SizedBox(),
          pw.SizedBox(),
        ],
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DETALLE DE ASISTENCIAS',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: _primaryColor, width: 1),
          children: tableRows,
        ),
      ],
    );
  }

  pw.TableRow _buildAttendanceRow(AsistenciaConDatos a) {
    final asistio = a.asistencia.asistio;
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            a.persona.nombreCompleto,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            a.persona.identificador ?? 'N/A',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            asistio ? 'Sí' : 'No',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: asistio ? _successColor : PdfColors.red,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            a.asistencia.metodoRegistro.value,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            a.asistencia.fechaRegistro != null
                ? _formatDate(a.asistencia.fechaRegistro!)
                : 'N/A',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _buildTotalCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Pie de página
  pw.Widget _buildFooter() {
    final now = DateTime.now();
    final fechaGeneracion =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} a las '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 32),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _lightGray,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Generado el $fechaGeneracion',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Sistema de Gestión de Asistencia - Sindicato',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helpers

  /// Gráfico de barras para distribución de asistencias
  pw.Widget _buildBarChart() {
    if (_totalAsistencias == 0) {
      return pw.Container();
    }

    final barWidth = 150.0;
    final barHeight = 30.0;
    final asistiendoWidth = (_asistieron / _totalAsistencias) * barWidth;
    final noAsistioWidth = (_noAsistieron / _totalAsistencias) * barWidth;

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _mediumGray, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Distribución de Asistencias',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              // Barra asistieron
              pw.Container(
                width: asistiendoWidth,
                height: barHeight,
                decoration: pw.BoxDecoration(
                  color: _successColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                'Asistieron: $_asistieron',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              // Barra no asistieron
              pw.Container(
                width: noAsistioWidth,
                height: barHeight,
                decoration: pw.BoxDecoration(
                  color: PdfColors.red,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                'No Asistieron: $_noAsistieron',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 140,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: _lightGray,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatCard(
    String label,
    String value,
    String icon, {
    PdfColor? color,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _lightGray,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: color ?? _primaryColor, width: 1),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              icon,
              style: const pw.TextStyle(fontSize: 24),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                color: color ?? _secondaryColor,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color ?? _primaryColor,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTipoReunion(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'presencial':
        return 'Presencial';
      case 'virtual':
        return 'Virtual';
      case 'hibrida':
        return 'Híbrida';
      default:
        return tipo;
    }
  }
}
