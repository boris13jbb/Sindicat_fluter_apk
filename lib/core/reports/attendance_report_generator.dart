import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/asistencia/asistencia.dart';

/// Palomita dibujada cuando no hay logo (evita glifos Unicode no soportados por la fuente PDF).
void _attendancePdfCheckGlyph(
  PdfGraphics canvas,
  PdfPoint size,
  PdfColor stroke,
) {
  final w = size.x;
  final h = size.y;
  final lw = math.max(1.2, math.min(w, h) * 0.1);
  canvas
    ..setStrokeColor(stroke)
    ..setLineWidth(lw)
    ..moveTo(w * 0.12, h * 0.50)
    ..lineTo(w * 0.40, h * 0.22)
    ..lineTo(w * 0.90, h * 0.78)
    ..strokePath();
}

/// Generador de reporte PDF de asistencias (2 páginas, estilo profesional premium).
class AttendanceReportGenerator {
  AttendanceReportGenerator({
    required this.asistencias,
    this.evento,
    this.reportLogoBytes,
  });

  final List<AsistenciaConDatos> asistencias;
  final EventoAsistencia? evento;

  /// Logo del reporte ([AppBrandingService], mismo origen que PDF de votación).
  final Uint8List? reportLogoBytes;

  late final int _totalAsistencias;
  late final int _asistieron;
  late final int _noAsistieron;
  late final double _porcentajeAsistencia;

  /// `true` cuando el detalle ocupó un [MultiPage] (más de [_maxRowsSinglePage] filas).
  late final bool _paginatedTableMode;

  /// Paleta alineada con mock `reporte_asistencia_profesional_premium`.
  static final PdfColor _purple = PdfColor.fromInt(0xFF5E48BA);
  static final PdfColor _purpleLight = PdfColor.fromInt(0xFFE8E0F5);
  static final PdfColor _green = PdfColor.fromInt(0xFF27A745);
  static final PdfColor _red = PdfColor.fromInt(0xFFDC3545);
  static final PdfColor _blue = PdfColor.fromInt(0xFF3B71ED);
  static final PdfColor _navy = PdfColor.fromInt(0xFF1A1F36);
  static final PdfColor _greyMuted = PdfColor.fromInt(0xFF6B7280);
  static final PdfColor _greyLine = PdfColor.fromInt(0xFFE0E4EB);
  static final PdfColor _greyBg = PdfColor.fromInt(0xFFF3F4F6);
  static final PdfColor _white = PdfColors.white;

  EventoAsistencia? get _effectiveEvento =>
      evento ?? (asistencias.isNotEmpty ? asistencias.first.evento : null);

  static const int _maxRowsSinglePage = 42;
  static const int _rowsPerChunk = 28;

  Future<Uint8List> generateReport() async {
    if (asistencias.isEmpty) {
      throw Exception('No hay datos de asistencias para generar el reporte');
    }

    _totalAsistencias = asistencias.length;
    _asistieron = asistencias.where((a) => a.asistencia.asistio).length;
    _noAsistieron = _totalAsistencias - _asistieron;
    _porcentajeAsistencia = _totalAsistencias > 0
        ? ((_asistieron / _totalAsistencias) * 100)
        : 0.0;
    _paginatedTableMode = asistencias.length > _maxRowsSinglePage;

    final pdf = pw.Document();
    final now = DateTime.now();

    if (!_paginatedTableMode) {
      // [MultiPage] permite que el [Column] canSpan reparta el contenido entre
      // hojas. Un [Page] + [Column] que excede la altura útil provoca en el
      // motor flex un corte silencioso: solo se pintan los primeros hijos
      // (cabecera + regla) y el resto queda en blanco.
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 30),
          maxPages: 40,
          build: (_) => [_buildPage1CombinedTable(now)],
        ),
      );
    } else {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 30),
          build: (_) => [
            _buildPage1Top(now, pageBadge: '1', totalDocPagesHint: '?'),
            _sectionHeading(
              '3. Detalle de asistencia',
              'Registro individual capturado por el sistema',
            ),
            ..._tableChunks(includeHeaderEveryChunk: true),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 34, vertical: 30),
        maxPages: 20,
        build: (_) => [_buildPage2(now)],
      ),
    );

    return pdf.save();
  }

  /// Página 1 completa cuando la tabla cabe en una sola hoja (mock).
  pw.Widget _buildPage1CombinedTable(DateTime now) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _pdfTopHeader(now, pageNumerator: '1', pageDenominator: '2'),
        pw.SizedBox(height: 10),
        _divider(),
        pw.SizedBox(height: 14),
        _heroTitleCard(),
        pw.SizedBox(height: 20),
        _sectionHeading(
          '1. Resumen ejecutivo',
          'Indicadores principales del control de asistencia',
        ),
        pw.SizedBox(height: 12),
        _kpiRow(),
        pw.SizedBox(height: 20),
        _sectionHeading(
          '2. Distribución de asistencias',
          'Comparativo visual de asistencia y ausencia',
        ),
        pw.SizedBox(height: 12),
        _distributionCard(),
        pw.SizedBox(height: 18),
        _sectionHeading(
          '3. Detalle de asistencia',
          'Registro individual capturado por el sistema',
        ),
        pw.SizedBox(height: 10),
        _attendanceTable(
          asistencias,
          showHeader: true,
          totalRow: _footerTotalRow(),
        ),
        pw.SizedBox(height: 16),
        _pageFooter(now, pageText: 'Página 1/2'),
      ],
    );
  }

  /// Cabeceras + KPI + donut cuando la tabla se pagina con MultiPage (muchas filas).
  pw.Widget _buildPage1Top(
    DateTime now, {
    required String pageBadge,
    required String totalDocPagesHint,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _pdfTopHeader(
          now,
          pageNumerator: pageBadge,
          pageDenominator: totalDocPagesHint,
        ),
        pw.SizedBox(height: 10),
        _divider(),
        pw.SizedBox(height: 14),
        _heroTitleCard(),
        pw.SizedBox(height: 20),
        _sectionHeading(
          '1. Resumen ejecutivo',
          'Indicadores principales del control de asistencia',
        ),
        pw.SizedBox(height: 12),
        _kpiRow(),
        pw.SizedBox(height: 20),
        _sectionHeading(
          '2. Distribución de asistencias',
          'Comparativo visual de asistencia y ausencia',
        ),
        pw.SizedBox(height: 12),
        _distributionCard(),
        pw.SizedBox(height: 18),
      ],
    );
  }

  List<pw.Widget> _tableChunks({required bool includeHeaderEveryChunk}) {
    final out = <pw.Widget>[];
    for (var i = 0; i < asistencias.length; i += _rowsPerChunk) {
      final end = math.min(i + _rowsPerChunk, asistencias.length);
      final chunk = asistencias.sublist(i, end);
      out.add(
        _attendanceTable(
          chunk,
          showHeader: includeHeaderEveryChunk || i == 0,
          totalRow: end == asistencias.length ? _footerTotalRow() : null,
        ),
      );
      if (end < asistencias.length) {
        out.add(pw.SizedBox(height: 12));
      }
    }
    return out;
  }

  pw.TableRow _footerTotalRow() {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: _greyBg),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            'TOTAL',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
              color: _navy,
            ),
          ),
        ),
        pw.SizedBox(),
        _totalCellUnderAsistio('$_asistieron'),
        pw.SizedBox(),
        pw.SizedBox(),
      ],
    );
  }

  pw.Widget _buildPage2(DateTime now) {
    final metodo = _metodoEjemploInterpretacion();
    final duplicados = _tieneIdentificadoresDuplicados();
    final badgeNum = _paginatedTableMode ? 'cierre' : '2';
    final badgeDen = _paginatedTableMode ? '—' : '2';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _pdfTopHeader(now, pageNumerator: badgeNum, pageDenominator: badgeDen),
        pw.SizedBox(height: 10),
        _divider(),
        pw.SizedBox(height: 14),
        _accentCard(
          title: 'ANÁLISIS Y VALIDACIÓN DEL REPORTE',
          subtitle: 'Reporte preparado para revisión administrativa y archivo.',
        ),
        pw.SizedBox(height: 18),
        _sectionHeading(
          '4. Interpretación automática',
          'Lectura resumida de los datos registrados',
        ),
        pw.SizedBox(height: 10),
        _plainCard(
          pw.Text(
            _textoInterpretacionAutomatica(metodo),
            style: pw.TextStyle(fontSize: 9, color: _navy, lineSpacing: 1.25),
          ),
        ),
        pw.SizedBox(height: 16),
        _sectionHeading(
          '5. Calidad del registro',
          'Validaciones recomendadas para consistencia del reporte',
        ),
        pw.SizedBox(height: 10),
        _plainCard(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _qualityRow(
                color: duplicados ? _red : _green,
                title: duplicados
                    ? 'Registros repetidos detectados'
                    : 'Registro único',
                body: duplicados
                    ? 'Hay identificadores con más de un documento en el detalle.'
                    : 'Los identificadores aparecen como máximo una vez en este detalle.',
              ),
              pw.SizedBox(height: 12),
              _qualityRow(
                color: _blue,
                title: 'Método validado',
                body:
                    'El registro ejemplo fue capturado mediante ${_metodoEjemploInterpretacion()}.',
              ),
              pw.SizedBox(height: 12),
              _qualityRow(
                color: _noAsistieron > 0
                    ? PdfColor.fromInt(0xFFE8A317)
                    : _green,
                title: _noAsistieron > 0
                    ? 'Ausencias registradas'
                    : 'Sin ausencias',
                body: _noAsistieron > 0
                    ? 'Hay $_noAsistieron filas con asistencia no confirmada.'
                    : 'No se registran personas pendientes o ausentes en estas filas.',
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        _sectionHeading(
          '6. Validación y cierre',
          'Constancia de generación del documento',
        ),
        pw.SizedBox(height: 10),
        _validationCard(now),
        pw.SizedBox(height: 28),
        _pageFooter(
          now,
          pageText: _paginatedTableMode
              ? 'Cierre del documento — análisis'
              : 'Página 2/2',
        ),
      ],
    );
  }

  // --- Layout pieces ---

  /// Marca en cabecera (círculo) o bloque de validación: imagen si existe, si no palomita vectorial.
  pw.Widget _brandingMark({required double size, required bool circular}) {
    final bytes = reportLogoBytes;
    if (bytes != null && bytes.isNotEmpty) {
      final radius = circular ? size / 2 : 8.0;
      final image = pw.Image(
        pw.MemoryImage(bytes),
        fit: pw.BoxFit.cover,
        width: size,
        height: size,
      );
      return pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(radius),
          border: pw.Border.all(color: _purple, width: 1.6),
          color: _purpleLight,
        ),
        child: circular
            ? pw.ClipOval(child: image)
            : pw.ClipRRect(
                horizontalRadius: 8,
                verticalRadius: 8,
                child: image,
              ),
      );
    }

    void paintCheck(PdfGraphics canvas, PdfPoint s) =>
        _attendancePdfCheckGlyph(canvas, s, _purple);
    if (circular) {
      return pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(
          color: _purpleLight,
          shape: pw.BoxShape.circle,
          border: pw.Border.all(color: _purple, width: 2),
        ),
        alignment: pw.Alignment.center,
        child: pw.CustomPaint(
          size: PdfPoint(size * 0.55, size * 0.55),
          painter: paintCheck,
        ),
      );
    }
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: _purpleLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _purple, width: 1.2),
      ),
      alignment: pw.Alignment.center,
      child: pw.CustomPaint(
        size: PdfPoint(size * 0.55, size * 0.55),
        painter: paintCheck,
      ),
    );
  }

  pw.Widget _pdfTopHeader(
    DateTime now, {
    required String pageNumerator,
    required String pageDenominator,
  }) {
    final badge = pageDenominator == '?'
        ? 'Sección inicial'
        : pageNumerator == 'cierre' && pageDenominator == '—'
        ? 'Análisis — cierre'
        : 'Página $pageNumerator de $pageDenominator';
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _brandingMark(size: 38, circular: true),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SISTEMA DE GESTIÓN DE ASISTENCIA',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Sindicato - Reporte automático para control y auditoría',
                  style: pw.TextStyle(fontSize: 8.5, color: _greyMuted),
                ),
              ],
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _purpleLight,
            borderRadius: pw.BorderRadius.circular(40),
          ),
          child: pw.Text(
            badge,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _purple,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _divider() => pw.Container(height: 1, color: _greyLine);

  pw.Widget _heroTitleCard() {
    final estado = _estadoEtiquetas();
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(12),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            blurRadius: 6,
            offset: const PdfPoint(0, 2),
          ),
        ],
      ),
      child: pw.Table(
        columnWidths: {
          0: const pw.FixedColumnWidth(6),
          1: const pw.FlexColumnWidth(),
        },
        children: [
          pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.full,
            children: [
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: _purple,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(12),
                    bottomLeft: pw.Radius.circular(12),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(14, 16, 14, 16),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'REPORTE DE ASISTENCIA',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: _navy,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            _effectiveEvento != null
                                ? 'Resumen consolidado de registros del evento: ${_effectiveEvento!.nombre}'
                                : 'Resumen consolidado de registros del evento',
                            style: pw.TextStyle(fontSize: 9, color: _greyMuted),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFE8F8EE),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'ESTADO',
                            style: pw.TextStyle(
                              fontSize: 7,
                              color: estado.badgeFg,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            estado.titulo,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: estado.badgeFg,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '${_porcentajeAsistencia.toStringAsFixed(1)}% de asistencia',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: estado.badgeFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ({String titulo, PdfColor badgeFg}) _estadoEtiquetas() {
    if (_asistieron == _totalAsistencias && _totalAsistencias > 0) {
      return (titulo: 'COMPLETO', badgeFg: _green);
    }
    if (_asistieron == 0) {
      return (titulo: 'SIN CONFIRMACIONES', badgeFg: _red);
    }
    return (titulo: 'EN REVISIÓN', badgeFg: PdfColor.fromInt(0xFFB8860B));
  }

  pw.Widget _sectionHeading(String title, String subtitle) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 4,
          height: 28,
          margin: const pw.EdgeInsets.only(top: 2, right: 10),
          decoration: pw.BoxDecoration(
            color: _purple,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                subtitle,
                style: pw.TextStyle(fontSize: 8, color: _greyMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _kpiRow() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _kpiMiniCard(
            label: 'TOTAL REGISTROS',
            value: '$_totalAsistencias',
            footer: 'Personas evaluadas',
            accent: _purple,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _kpiMiniCard(
            label: 'ASISTIERON',
            value: '$_asistieron',
            footer: 'Registros confirmados',
            accent: _green,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _kpiMiniCard(
            label: 'NO ASISTIERON',
            value: '$_noAsistieron',
            footer: 'Sin registro',
            accent: _red,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _kpiMiniCard(
            label: 'PORCENTAJE',
            value: '${_porcentajeAsistencia.toStringAsFixed(1)}%',
            footer: 'Cumplimiento general',
            accent: _blue,
          ),
        ),
      ],
    );
  }

  pw.Widget _kpiMiniCard({
    required String label,
    required String value,
    required String footer,
    required PdfColor accent,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _greyLine),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            blurRadius: 4,
            offset: const PdfPoint(0, 1),
          ),
        ],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 34,
            height: 34,
            decoration: pw.BoxDecoration(
              color: accent,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
              color: _greyMuted,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            footer,
            style: pw.TextStyle(fontSize: 7, color: _greyMuted),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  pw.Widget _distributionCard() {
    final pctA = _porcentajeAsistencia;
    final pctN = _totalAsistencias > 0 ? 100 - pctA : 0;
    final wAsis = pctA.clamp(0, 100) / 100.0;
    final wNas = pctN.clamp(0, 100) / 100.0;

    final datasets = _pieDatasets();

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _greyLine),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            blurRadius: 5,
            offset: const PdfPoint(0, 2),
          ),
        ],
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 130,
            height: 130,
            child: pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.Chart(
                  grid: pw.PieGrid(startAngle: -math.pi / 2),
                  datasets: datasets,
                ),
                pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      '${pctA.toStringAsFixed(0)}%',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: _green,
                      ),
                    ),
                    pw.Text(
                      'asistencia',
                      style: pw.TextStyle(fontSize: 8, color: _greyMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _barRow(
                  label: 'Asistieron',
                  fill: wAsis,
                  fillColor: _green,
                  trackColor: PdfColor.fromInt(0xFFE8E8E8),
                  detail:
                      '$_asistieron persona${_asistieron == 1 ? '' : 's'} · ${pctA.toStringAsFixed(1)}%',
                ),
                pw.SizedBox(height: 14),
                _barRow(
                  label: 'No asistieron',
                  fill: wNas,
                  fillColor: PdfColor.fromInt(0xFFE0E0E0),
                  trackColor: PdfColor.fromInt(0xFFE8E8E8),
                  detail:
                      '$_noAsistieron persona${_noAsistieron == 1 ? '' : 's'} · ${pctN.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _barRow({
    required String label,
    required double fill,
    required PdfColor fillColor,
    required PdfColor trackColor,
    required String detail,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
            pw.Text(
              detail,
              style: pw.TextStyle(fontSize: 8, color: _greyMuted),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          height: 12,
          decoration: pw.BoxDecoration(
            color: trackColor,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                flex: math.max((fill.clamp(0.0, 1.0) * 1000).round(), 4),
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    color: fillColor,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                ),
              ),
              pw.Expanded(
                flex: math.max(
                  1000 - math.max((fill.clamp(0.0, 1.0) * 1000).round(), 4),
                  4,
                ),
                child: pw.SizedBox(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _attendanceTable(
    List<AsistenciaConDatos> rows, {
    required bool showHeader,
    pw.TableRow? totalRow,
  }) {
    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 8,
      color: _white,
    );
    final dataStyle = pw.TextStyle(fontSize: 8, color: _navy);

    final headerRow = pw.TableRow(
      decoration: pw.BoxDecoration(color: _navy),
      children: [
        _tc('Persona', headerStyle),
        _tc('Identificador', headerStyle),
        _tc('Asistió', headerStyle),
        _tc('Método', headerStyle),
        _tc('Fecha registro', headerStyle),
      ],
    );

    final body = <pw.TableRow>[
      if (showHeader) headerRow,
      for (final a in rows)
        pw.TableRow(
          children: [
            _tc(a.persona.nombreCompleto, dataStyle),
            _tc(a.persona.identificador ?? 'N/A', dataStyle),
            _tc(
              a.asistencia.asistio ? 'Sí' : 'No',
              dataStyle.copyWith(
                color: a.asistencia.asistio ? _green : _red,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            _tc(a.asistencia.metodoRegistro.value, dataStyle),
            _tc(
              a.asistencia.fechaRegistro != null
                  ? _formatDate(a.asistencia.fechaRegistro!)
                  : 'N/A',
              dataStyle,
            ),
          ],
        ),
      if (totalRow != null) totalRow,
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _greyLine, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.6),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(0.9),
        3: const pw.FlexColumnWidth(1.3),
        4: const pw.FlexColumnWidth(1.6),
      },
      children: body,
    );
  }

  pw.Widget _tc(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: style),
    );
  }

  pw.Widget _totalCellUnderAsistio(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 8,
          color: _navy,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  List<pw.Dataset> _pieDatasets() {
    const inner = 42.0;
    if (_asistieron <= 0 && _noAsistieron <= 0) {
      return [
        pw.PieDataSet(
          value: 1,
          color: _greyMuted,
          innerRadius: inner,
          legendPosition: pw.PieLegendPosition.none,
          drawBorder: false,
        ),
      ];
    }
    if (_noAsistieron <= 0) {
      return [
        pw.PieDataSet(
          value: math.max(_asistieron, 1),
          color: _green,
          innerRadius: inner,
          legendPosition: pw.PieLegendPosition.none,
          drawBorder: false,
        ),
      ];
    }
    if (_asistieron <= 0) {
      return [
        pw.PieDataSet(
          value: math.max(_noAsistieron, 1),
          color: PdfColor.fromInt(0xFFE8E8E8),
          innerRadius: inner,
          legendPosition: pw.PieLegendPosition.none,
          drawBorder: false,
        ),
      ];
    }
    return [
      pw.PieDataSet(
        value: _asistieron,
        color: _green,
        innerRadius: inner,
        legendPosition: pw.PieLegendPosition.none,
        drawBorder: false,
      ),
      pw.PieDataSet(
        value: _noAsistieron,
        color: PdfColor.fromInt(0xFFE8E8E8),
        innerRadius: inner,
        legendPosition: pw.PieLegendPosition.none,
        drawBorder: false,
      ),
    ];
  }

  pw.Widget _accentCard({required String title, required String subtitle}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(12),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            blurRadius: 6,
            offset: const PdfPoint(0, 2),
          ),
        ],
      ),
      child: pw.Table(
        columnWidths: {
          0: const pw.FixedColumnWidth(6),
          1: const pw.FlexColumnWidth(),
        },
        children: [
          pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.full,
            children: [
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: _purple,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(12),
                    bottomLeft: pw.Radius.circular(12),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(14, 16, 14, 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      subtitle,
                      style: pw.TextStyle(fontSize: 9, color: _greyMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _plainCard(pw.Widget child) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _greyLine),
      ),
      child: child,
    );
  }

  String _textoInterpretacionAutomatica(String metodoEjemplo) {
    return 'Este reporte consolida $_totalAsistencias persona${_totalAsistencias == 1 ? '' : 's'} '
        'evaluada${_totalAsistencias == 1 ? '' : 's'}, $_asistieron asistencia${_asistieron == 1 ? '' : 's'} '
        'confirmada${_asistieron == 1 ? '' : 's'}, con énfasis en el método típico $metodoEjemplo y un '
        'cumplimiento del ${_porcentajeAsistencia.toStringAsFixed(1)}% sobre el conjunto registrado.';
  }

  String _metodoEjemploInterpretacion() {
    final conMetodo = asistencias.where((a) => a.asistencia.asistio).toList();
    if (conMetodo.isEmpty) {
      return asistencias.isNotEmpty
          ? asistencias.first.asistencia.metodoRegistro.value
          : 'MANUAL';
    }
    final counts = <String, int>{};
    for (final a in conMetodo) {
      final k = a.asistencia.metodoRegistro.value;
      counts[k] = (counts[k] ?? 0) + 1;
    }
    var best = '';
    var n = 0;
    counts.forEach((k, v) {
      if (v > n) {
        n = v;
        best = k;
      }
    });
    return best.isEmpty ? 'MANUAL' : best;
  }

  bool _tieneIdentificadoresDuplicados() {
    final keys = <String>{};
    for (final a in asistencias) {
      final id = (a.persona.identificador ?? a.persona.id).trim();
      if (id.isEmpty) continue;
      if (keys.contains(id)) return true;
      keys.add(id);
    }
    return false;
  }

  pw.Widget _qualityRow({
    required PdfColor color,
    required String title,
    required String body,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 22,
          height: 22,
          decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                body,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: _greyMuted,
                  lineSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _validationCard(DateTime now) {
    final fecha = _formatFooterDateTime(now);
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _greyLine),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _brandingMark(size: 48, circular: true),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Documento generado automáticamente',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Sistema de Gestión de Asistencia - Sindicato',
                      style: pw.TextStyle(fontSize: 8, color: _greyMuted),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Fecha de generación: $fecha',
                      style: pw.TextStyle(fontSize: 8, color: _greyMuted),
                    ),
                    pw.SizedBox(height: 6),
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'Estado del reporte: ',
                            style: pw.TextStyle(fontSize: 8, color: _greyMuted),
                          ),
                          pw.TextSpan(
                            text: 'Consolidado para revisión',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: _green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Row(
            children: [
              pw.Expanded(child: _sigLineLabel('Responsable de asistencia')),
              pw.SizedBox(width: 36),
              pw.Expanded(child: _sigLineLabel('Administrador del sistema')),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _sigLineLabel(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(height: 1, color: _navy),
        pw.SizedBox(height: 6),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7.5, color: _greyMuted),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  pw.Widget _pageFooter(DateTime now, {required String pageText}) {
    final fecha = _formatFooterDateTime(now);
    return pw.Column(
      children: [
        pw.Container(height: 1, color: _greyLine),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Sistema de Gestión de Asistencia - Sindicato',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _greyMuted,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Generado el $fecha',
                  style: pw.TextStyle(fontSize: 7.5, color: _greyMuted),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  pageText,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _greyMuted,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Documento interno / archivo institucional',
                  style: pw.TextStyle(fontSize: 7.5, color: _greyMuted),
                ),
              ],
            ),
          ],
        ),
      ],
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

  String _formatFooterDateTime(DateTime now) {
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} a las '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }
}
