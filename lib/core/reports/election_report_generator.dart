import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import '../models/election.dart';
import '../models/candidate.dart';

/// Generador profesional de reportes PDF para resultados electorales.
/// Incluye diseño profesional con encabezado, estadísticas, tablas y gráficos.
class ElectionReportGenerator {
  ElectionReportGenerator({
    required this.election,
    required this.candidates,
    required this.totalVotes,
  });

  final Election election;
  final List<Candidate> candidates;
  final int totalVotes;

  // Colores corporativos
  static final _primaryColor = PdfColor.fromInt(0xFF6750A4);
  static final _secondaryColor = PdfColor.fromInt(0xFF625B71);
  static final _accentColor = PdfColor.fromInt(0xFFFFD700);
  static final _successColor = PdfColor.fromInt(0xFF4CAF50);
  static final _lightGray = PdfColor.fromInt(0xFFF5F5F5);
  static final _mediumGray = PdfColor.fromInt(0xFFE0E0E0);

  /// Genera el PDF completo con todas las secciones
  Future<Uint8List> generateReport() async {
    final pdf = pw.Document();
    final sortedCandidates = List<Candidate>.from(candidates)
      ..sort((a, b) => b.voteCount.compareTo(a.voteCount));

    final winner = sortedCandidates.isNotEmpty ? sortedCandidates.first : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildHeader(),
          pw.SizedBox(height: 30),
          _buildElectionInfo(),
          pw.SizedBox(height: 30),
          _buildGeneralStats(winner),
          pw.SizedBox(height: 30),
          _buildResultsTitle(),
          pw.SizedBox(height: 16),
          _buildResultsTable(sortedCandidates),
          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  /// Encabezado con título y branding
  pw.Widget _buildHeader() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.all(40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'REPORTE DE RESULTADOS\nELECTORALES',
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              height: 1.3,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            election.title,
            style: pw.TextStyle(
              fontSize: 18,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Información detallada de la elección
  pw.Widget _buildElectionInfo() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'INFORMACIÓN DE LA ELECCIÓN',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.SizedBox(height: 12),
        _buildInfoRow('Título:', election.title),
        _buildInfoRow('Descripción:', election.description),
        _buildInfoRow('Fecha de Inicio:', _formatDate(election.startDate)),
        _buildInfoRow('Fecha de Fin:', _formatDate(election.endDate)),
        _buildInfoRow('Estado:', election.isActive ? 'Activa' : 'Finalizada'),
        _buildInfoRow('ID de Elección:', election.id),
      ],
    );
  }

  /// Fila de información con etiqueta y valor
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 180,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _lightGray,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  /// Estadísticas generales
  pw.Widget _buildGeneralStats(Candidate? winner) {
    final winnerName = winner?.name ?? 'N/A';
    final winnerPercentage = totalVotes > 0 && winner != null
        ? ((winner.voteCount / totalVotes) * 100).toStringAsFixed(2)
        : '0.00';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ESTADÍSTICAS GENERALES',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildStatCard('Total de Votos', '$totalVotes', '🗳️'),
            pw.SizedBox(width: 24),
            _buildStatCard('Candidatos', '${candidates.length}', '👥'),
            pw.SizedBox(width: 24),
            _buildStatCard(
              'Ganador',
              '$winnerName\n($winnerPercentage%)',
              '🏆',
            ),
          ],
        ),
      ],
    );
  }

  /// Tarjeta de estadística individual
  pw.Widget _buildStatCard(String label, String value, String icon) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: _lightGray,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: _primaryColor, width: 1),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              icon,
              style: const pw.TextStyle(fontSize: 32),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                color: _secondaryColor,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Título de resultados por candidato
  pw.Widget _buildResultsTitle() {
    return pw.Text(
      'RESULTADOS POR CANDIDATO',
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: _primaryColor,
      ),
    );
  }

  /// Tabla de resultados detallada
  pw.Widget _buildResultsTable(List<Candidate> sortedCandidates) {
    final children = <pw.TableRow>[
      // Encabezado de tabla
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _primaryColor),
        children: [
          _buildHeaderCell('Posición'),
          _buildHeaderCell('Candidato'),
          _buildHeaderCell('Votos'),
          _buildHeaderCell('Porcentaje'),
        ],
      ),
    ];

    // Filas de datos
    for (var i = 0; i < sortedCandidates.length; i++) {
      final candidate = sortedCandidates[i];
      final rank = i + 1;
      final percentage = totalVotes > 0
          ? ((candidate.voteCount / totalVotes) * 100)
          : 0.0;
      final isWinner = rank == 1 && totalVotes > 0;
      final isEven = i % 2 == 0;

      children.add(
        pw.TableRow(
          decoration: isEven ? pw.BoxDecoration(color: _lightGray) : null,
          children: [
            _buildDataCell(
              '$rank',
              isWinner
                  ? pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: _successColor,
                    )
                  : null,
              isWinner,
            ),
            _buildDataCell(
              candidate.name,
              isWinner
                  ? pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: _successColor,
                    )
                  : null,
              false,
            ),
            _buildDataCell(
              '${candidate.voteCount}',
              isWinner
                  ? pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: _successColor,
                    )
                  : null,
              false,
              alignRight: true,
            ),
            _buildDataCell(
              '${percentage.toStringAsFixed(2)}%',
              isWinner
                  ? pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: _successColor,
                    )
                  : null,
              false,
              alignRight: true,
            ),
          ],
        ),
      );
    }

    // Fila de total
    children.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _mediumGray),
        children: [
          _buildTotalCell('TOTAL'),
          pw.SizedBox(),
          _buildTotalCell('$totalVotes', alignRight: true),
          _buildTotalCell(
            '${totalVotes > 0 ? 100.00 : 0.00}%',
            alignRight: true,
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _primaryColor, width: 1),
      children: children,
    );
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 11,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _buildDataCell(
    String text,
    pw.TextStyle? style,
    bool highlight, {
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: style ?? const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  pw.Widget _buildTotalCell(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      ),
    );
  }

  /// Pie de página con información de generación
  pw.Widget _buildFooter() {
    final now = DateTime.now();
    final fechaGeneracion =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} a las '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 40),
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _lightGray,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Generado el $fechaGeneracion',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Sistema de Votación Electrónica - Sindicato',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Formatea timestamp a fecha legible
  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
