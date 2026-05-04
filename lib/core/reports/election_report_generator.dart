import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

import '../models/candidate.dart';
import '../models/election.dart';

/// Generador de reporte PDF de resultados (2 páginas, estilo certificado).
class ElectionReportGenerator {
  ElectionReportGenerator({
    required this.election,
    required this.candidates,
    required this.totalVotes,
  });

  final Election election;
  final List<Candidate> candidates;
  final int totalVotes;

  static final PdfColor _primary = PdfColor.fromInt(0xFF4A328C);
  static final PdfColor _primaryLight = PdfColor.fromInt(0xFFE8DEF8);
  static final PdfColor _primaryDark = PdfColor.fromInt(0xFF381F6B);
  static final PdfColor _green = PdfColor.fromInt(0xFF27AE60);
  static final PdfColor _blue = PdfColor.fromInt(0xFF448AFF);
  static final PdfColor _greyBg = PdfColor.fromInt(0xFFF5F7FA);
  static final PdfColor _greyLine = PdfColor.fromInt(0xFFE0E4EB);
  static final PdfColor _greyMuted = PdfColor.fromInt(0xFF6B7280);
  static final PdfColor _greyFooter = PdfColor.fromInt(0xFF9CA3AF);
  static final PdfColor _winnerBg = PdfColor.fromInt(0xFFE8F8EE);

  Future<Uint8List> generateReport() async {
    final pdf = pw.Document();
    final sorted = List<Candidate>.from(candidates)
      ..sort((a, b) => b.voteCount.compareTo(a.voteCount));
    final winner = sorted.isNotEmpty ? sorted.first : null;
    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        build: (ctx) => _page1(ctx, sorted, winner, now),
      ),
    );
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        build: (ctx) => _page2(ctx, sorted, winner, now),
      ),
    );

    return pdf.save();
  }

  pw.Widget _page1(
    pw.Context ctx,
    List<Candidate> sorted,
    Candidate? winner,
    DateTime now,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _pdfPageHeader(page: 1, totalPages: 2),
        pw.SizedBox(height: 10),
        _divider(),
        pw.SizedBox(height: 14),
        _heroBlock(winner),
        pw.SizedBox(height: 18),
        _sectionHeading(
          '1. Información de la elección',
          'Datos principales registrados en el sistema',
          accent: _blue,
        ),
        pw.SizedBox(height: 8),
        _electionInfoGrid(),
        pw.SizedBox(height: 16),
        _sectionHeading(
          '2. Indicadores generales',
          'Resumen cuantitativo del proceso electoral',
          accent: _primary,
        ),
        pw.SizedBox(height: 10),
        _indicatorCards(winner),
        pw.SizedBox(height: 16),
        _sectionHeading(
          '3. Visualización de resultados',
          'Distribución de votos por candidato',
          accent: _primary,
        ),
        pw.SizedBox(height: 10),
        _visualizationRow(sorted, winner),
        pw.Spacer(),
        _pageFooter(now, page: 1, totalPages: 2),
      ],
    );
  }

  pw.Widget _page2(
    pw.Context ctx,
    List<Candidate> sorted,
    Candidate? winner,
    DateTime now,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _pdfPageHeader(page: 2, totalPages: 2),
        pw.SizedBox(height: 10),
        _divider(),
        pw.SizedBox(height: 14),
        _detailTitleCard(),
        pw.SizedBox(height: 16),
        _sectionHeading(
          '4. Resultados por candidato',
          'Ordenado por cantidad de votos obtenidos',
          accent: _primary,
        ),
        pw.SizedBox(height: 8),
        _resultsTable(sorted),
        pw.SizedBox(height: 14),
        _sectionHeading(
          '5. Resumen ejecutivo',
          'Interpretación automática de resultados',
          accent: _primary,
        ),
        pw.SizedBox(height: 8),
        _executiveSummary(sorted, winner),
        pw.SizedBox(height: 14),
        _sectionHeading(
          '6. Validación y cierre',
          'Constancia de generación del documento',
          accent: _primary,
        ),
        pw.SizedBox(height: 8),
        _validationCard(now),
        pw.Spacer(),
        _pageFooter(now, page: 2, totalPages: 2),
      ],
    );
  }

  pw.Widget _pdfPageHeader({required int page, required int totalPages}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 36,
              height: 36,
              decoration: pw.BoxDecoration(
                color: _primaryLight,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _primary, width: 1),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                '◆',
                style: pw.TextStyle(
                  fontSize: 16,
                  color: _primary,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SISTEMA DE VOTACIÓN ELECTRÓNICA',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryDark,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Sindicato · Reporte certificado de resultados',
                  style: pw.TextStyle(fontSize: 8.5, color: _greyMuted),
                ),
              ],
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _primaryLight,
            borderRadius: pw.BorderRadius.circular(20),
          ),
          child: pw.Text(
            'Página $page de $totalPages',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _divider() {
    return pw.Container(height: 1, color: _greyLine);
  }

  pw.Widget _heroBlock(Candidate? winner) {
    final status = _statusLabel();
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _greyLine),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            blurRadius: 4,
            offset: const PdfPoint(0, 2),
          ),
        ],
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 5,
            height: 88,
            decoration: pw.BoxDecoration(
              color: _primary,
              borderRadius: pw.BorderRadius.circular(3),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'REPORTE DE RESULTADOS ELECTORALES',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryDark,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Elección: ',
                        style: pw.TextStyle(fontSize: 10, color: _greyMuted),
                      ),
                      pw.TextSpan(
                        text: election.title,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            width: 132,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _primaryDark,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ESTADO',
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  status.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'ID: ${election.id}',
                  style: pw.TextStyle(fontSize: 6.5, color: PdfColors.white),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel() {
    final s = election.effectiveStatus();
    switch (s) {
      case ElectionStatus.active:
        return 'Activa';
      case ElectionStatus.closed:
        return 'Finalizada';
      case ElectionStatus.draft:
        return 'Borrador';
    }
  }

  pw.Widget _sectionHeading(
    String title,
    String subtitle, {
    required PdfColor accent,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 3,
          height: 28,
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryDark,
                ),
              ),
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

  pw.Widget _electionInfoGrid() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _greyBg,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _greyLine),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _gridField('TÍTULO', election.title)),
              pw.SizedBox(width: 10),
              pw.Expanded(child: _gridField('DESCRIPCIÓN', election.description)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _gridField('ESTADO', _statusLabel())),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _gridField(
                  'FECHA DE INICIO',
                  _formatDate(election.startDate),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: _gridField(
                  'FECHA DE FIN',
                  _formatDate(election.endDate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _gridField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7,
            color: _greyMuted,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value.isEmpty ? '—' : value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _primaryDark,
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  pw.Widget _indicatorCards(Candidate? winner) {
    final winnerName = (totalVotes > 0 && winner != null) ? winner.name : '—';
    final winnerPct = (totalVotes > 0 && winner != null)
        ? ((winner.voteCount / totalVotes) * 100).toStringAsFixed(2)
        : '0.00';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _kpiCard(
            'Total de Votos',
            '$totalVotes',
            'Votos válidos registrados',
            _primary,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _kpiCard(
            'Candidatos',
            '${candidates.length}',
            'Postulantes habilitados',
            _blue,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _kpiCard(
            'Ganador',
            winnerName,
            '$winnerPct% de los votos',
            _green,
            valueIsName: true,
          ),
        ),
      ],
    );
  }

  pw.Widget _kpiCard(
    String title,
    String value,
    String footer,
    PdfColor accent, {
    bool valueIsName = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _greyLine),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            blurRadius: 3,
            offset: const PdfPoint(0, 1),
          ),
        ],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 28,
                height: 28,
                decoration: pw.BoxDecoration(
                  color: accent,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _greyMuted,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: valueIsName ? 12 : 18,
              fontWeight: pw.FontWeight.bold,
              color: valueIsName ? _green : _primaryDark,
            ),
            maxLines: 2,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            footer,
            style: pw.TextStyle(fontSize: 7.5, color: _greyMuted),
          ),
        ],
      ),
    );
  }

  pw.Widget _visualizationRow(List<Candidate> sorted, Candidate? winner) {
    final leader = sorted.isNotEmpty ? sorted.first : null;
    final leaderPct = (totalVotes > 0 && leader != null)
        ? ((leader.voteCount / totalVotes) * 100).round()
        : 0;
    final subtitle = leader != null && leader.voteCount > 0 ? 'lidera' : '—';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _greyLine),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 112,
            height: 112,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: _green, width: 14),
            ),
            alignment: pw.Alignment.center,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  '$leaderPct%',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _green,
                  ),
                ),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(fontSize: 8, color: _greyMuted),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sorted.length && i < 8; i++)
                  _candidateBarRow(sorted[i], i == 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _voteProgressBar(double pct, PdfColor barColor) {
    final radius = pw.BorderRadius.circular(5);
    if (pct >= 0.999) {
      return pw.Container(
        height: 10,
        decoration: pw.BoxDecoration(color: barColor, borderRadius: radius),
      );
    }
    if (pct <= 0.001) {
      return pw.Container(
        height: 10,
        decoration: pw.BoxDecoration(color: _greyBg, borderRadius: radius),
      );
    }
    const scale = 200;
    final f = math.max(1, (pct * scale).round());
    final e = math.max(1, scale - f);
    return pw.Row(
      children: [
        pw.Expanded(
          flex: f,
          child: pw.Container(
            height: 10,
            decoration: pw.BoxDecoration(color: barColor, borderRadius: radius),
          ),
        ),
        pw.Expanded(
          flex: e,
          child: pw.Container(
            height: 10,
            decoration: pw.BoxDecoration(color: _greyBg, borderRadius: radius),
          ),
        ),
      ],
    );
  }

  pw.Widget _candidateBarRow(Candidate c, bool isLeader) {
    final pct = totalVotes > 0 ? (c.voteCount / totalVotes) : 0.0;
    final pctStr = (pct * 100).toStringAsFixed(2);
    final barColor = isLeader ? _green : _primary;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: pw.BoxDecoration(
          color: isLeader ? _winnerBg : PdfColors.white,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(
            color: isLeader ? _green : _greyLine,
            width: isLeader ? 1 : 0.5,
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    c.name,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryDark,
                    ),
                  ),
                ),
                pw.Text(
                  '${c.voteCount} voto(s)   $pctStr%',
                  style: pw.TextStyle(fontSize: 9, color: _greyMuted),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            _voteProgressBar(pct, barColor),
          ],
        ),
      ),
    );
  }

  pw.Widget _detailTitleCard() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _greyLine),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            blurRadius: 4,
            offset: const PdfPoint(0, 2),
          ),
        ],
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 5,
            height: 52,
            decoration: pw.BoxDecoration(
              color: _primary,
              borderRadius: pw.BorderRadius.circular(3),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DETALLE OFICIAL POR CANDIDATO',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryDark,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Tabla consolidada para revisión, control y archivo electoral.',
                  style: pw.TextStyle(fontSize: 9, color: _greyMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _resultsTable(List<Candidate> sorted) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _primaryDark),
        children: [
          _th('Posición'),
          _th('Candidato'),
          _th('Votos'),
          _th('Porcentaje'),
        ],
      ),
    ];

    for (var i = 0; i < sorted.length; i++) {
      final c = sorted[i];
      final rank = i + 1;
      final pct = totalVotes > 0 ? (c.voteCount / totalVotes) * 100 : 0.0;
      final win = rank == 1 && totalVotes > 0 && c.voteCount > 0;
      final style = win
          ? pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: _green,
              fontSize: 10,
            )
          : const pw.TextStyle(fontSize: 10);

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isEven ? _greyBg : PdfColors.white,
          ),
          children: [
            _td('$rank', style),
            _td(c.name, style),
            _td('${c.voteCount}', style, right: true),
            _td('${pct.toStringAsFixed(2)}%', style, right: true),
          ],
        ),
      );
    }

    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _greyLine),
        children: [
          _td('TOTAL', pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          _td('', pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          _td(
            '$totalVotes',
            pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            right: true,
          ),
          _td(
            '${totalVotes > 0 ? '100.00' : '0.00'}%',
            pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            right: true,
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _primary, width: 0.8),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.1),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.3),
      },
      children: rows,
    );
  }

  pw.Widget _th(String t) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        t,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  pw.Widget _td(String t, pw.TextStyle style, {bool right = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        t,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: style,
      ),
    );
  }

  pw.Widget _executiveSummary(List<Candidate> sorted, Candidate? winner) {
    final title = election.title;
    final others = sorted.length > 1
        ? sorted.skip(1).map((c) => '"${c.name}" (${c.voteCount})').join(', ')
        : 'no hubo otros candidatos con votos';

    final body = totalVotes == 0
        ? 'En la elección "$title" no se registraron votos válidos al momento '
            'de generar este documento. El reporte sirve como constancia para '
            'transparencia y control interno.'
        : 'La elección "$title" registró un total de $totalVotes voto(s) '
            'válido(s). El candidato "${winner?.name ?? '—'}" obtuvo la mayor '
            'preferencia. '
            '${sorted.length > 1 ? 'Demás postulantes: $others.' : ''} '
            'Este documento constituye un respaldo documental para '
            'transparencia y archivo electoral.';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _greyLine),
      ),
      child: pw.Text(
        body,
        style: pw.TextStyle(fontSize: 9, height: 1.35, color: _primaryDark),
      ),
    );
  }

  pw.Widget _validationCard(DateTime now) {
    final fecha = _formatDateTime(now);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _greyLine),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 36,
                height: 36,
                decoration: pw.BoxDecoration(
                  color: _primaryLight,
                  shape: pw.BoxShape.circle,
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  '✓',
                  style: pw.TextStyle(
                    fontSize: 18,
                    color: _primary,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Documento generado automáticamente',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryDark,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Sistema de Votación Electrónica - Sindicato',
                      style: pw.TextStyle(fontSize: 9, color: _greyMuted),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Fecha de generación: $fecha',
                      style: pw.TextStyle(fontSize: 9, color: _greyMuted),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Estado del reporte: Consolidado para revisión',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(child: _signatureLine('Responsable electoral')),
              pw.SizedBox(width: 24),
              pw.Expanded(child: _signatureLine('Administrador del sistema')),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _signatureLine(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(height: 1, color: _greyMuted),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7.5, color: _greyMuted),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  pw.Widget _pageFooter(DateTime now, {required int page, required int totalPages}) {
    final fecha = _formatDateTime(now);
    return pw.Column(
      children: [
        _divider(),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Documento generado automáticamente · Sistema de Votación '
                    'Electrónica - Sindicato',
                    style: pw.TextStyle(fontSize: 7, color: _greyFooter),
                  ),
                  pw.Text(
                    'Fecha de generación: $fecha',
                    style: pw.TextStyle(fontSize: 7, color: _greyFooter),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Página $page/$totalPages',
                  style: pw.TextStyle(fontSize: 7, color: _greyFooter),
                ),
                pw.Text(
                  'Uso interno / archivo electoral',
                  style: pw.TextStyle(fontSize: 7, color: _greyFooter),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _formatDateTime(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        'a las ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
