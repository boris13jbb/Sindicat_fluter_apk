import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/import_log.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/import_service.dart';

/// Pantalla de importación masiva de socios desde CSV
class ImportMembersScreen extends StatefulWidget {
  const ImportMembersScreen({super.key});

  @override
  State<ImportMembersScreen> createState() => _ImportMembersScreenState();
}

class _ImportMembersScreenState extends State<ImportMembersScreen> {
  final ImportService _service = ImportService();

  bool _isProcessing = false;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String? _selectedFileType; // 'csv' o 'excel'
  ImportPreviewResult? _previewResult;
  String? _previewError;
  ImportLog? _lastImportLog;

  bool get _canImportSelectedFile =>
      _selectedFileBytes != null &&
      _selectedFileType != null &&
      _previewError == null &&
      (_previewResult?.canImport ?? true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Importar Socios',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instrucciones
            _buildInstructionsCard(),

            const SizedBox(height: 24),

            // Selector de archivo
            _buildFileSelector(),

            if (_previewResult != null || _previewError != null) ...[
              const SizedBox(height: 16),
              _buildPreviewCard(),
            ],

            const SizedBox(height: 24),

            // Botón importar
            if (_selectedFileBytes != null)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing || !_canImportSelectedFile
                      ? null
                      : _importFile,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    _isProcessing ? 'Procesando...' : 'Importar Archivo',
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // Resultado de última importación
            if (_lastImportLog != null) _buildImportResult(_lastImportLog!),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Instrucciones',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('El archivo debe contener las siguientes columnas:'),
            const SizedBox(height: 8),
            _buildBulletPoint('numero_socio (obligatorio)'),
            _buildBulletPoint('nombres (obligatorio)'),
            _buildBulletPoint('apellidos (obligatorio)'),
            _buildBulletPoint(
              'modalidad (obligatorio: A,B,C,D,E,N,N1,N2,X,Y,Z)',
            ),
            _buildBulletPoint('worker_code (recomendado para QR/votación)'),
            _buildBulletPoint('documento (opcional)'),
            _buildBulletPoint('email (opcional)'),
            _buildBulletPoint('telefono (opcional)'),
            const SizedBox(height: 12),
            Text(
              'Formatos soportados: .csv, .xlsx, .xls',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nota: Los números de socio duplicados serán omitidos.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _shareExcelTemplate,
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Plantilla Excel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildFileSelector() {
    return Card(
      child: InkWell(
        onTap: _selectFile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 64,
                color: _selectedFileBytes != null
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                _selectedFileName ?? 'Toca para seleccionar archivo',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (_selectedFileBytes == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Formatos soportados: .csv, .xlsx, .xls',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportResult(ImportLog log) {
    final isSuccess = log.isSuccessful;

    return Card(
      color: isSuccess ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Resultado de Importación',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildStatRow('Total de filas:', '${log.totalRows}'),
            _buildStatRow(
              'Importados:',
              '${log.successfulImports}',
              Colors.green,
            ),
            if (log.duplicatesFound > 0)
              _buildStatRow(
                'Duplicados:',
                '${log.duplicatesFound}',
                Colors.orange,
              ),
            if (log.errors > 0)
              _buildStatRow('Errores:', '${log.errors}', Colors.red),
            _buildStatRow(
              'Tasa de éxito:',
              '${log.successRate.toStringAsFixed(1)}%',
            ),

            if (log.errorDetails.isNotEmpty ||
                log.duplicateMemberNumbers.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              if (log.errorDetails.isNotEmpty) ...[
                Text(
                  'Detalles de errores:',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...log.errorDetails
                    .take(5)
                    .map(
                      (error) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $error',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                if (log.errorDetails.length > 5)
                  Text(
                    '... y ${log.errorDetails.length - 5} errores más',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
              if (log.duplicateMemberNumbers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Números de socio duplicados:',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...log.duplicateMemberNumbers
                    .take(5)
                    .map(
                      (number) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $number',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ),
                if (log.duplicateMemberNumbers.length > 5)
                  Text(
                    '... y ${log.duplicateMemberNumbers.length - 5} duplicados más',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final preview = _previewResult;
    final hasError = _previewError != null;
    final color = hasError || (preview?.hasWarnings ?? false)
        ? Colors.orange
        : Colors.green;

    return Card(
      color: hasError ? Colors.red[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasError
                      ? Icons.error_outline
                      : preview!.hasWarnings
                      ? Icons.warning_amber_outlined
                      : Icons.fact_check_outlined,
                  color: hasError ? Colors.red : color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prevalidación del archivo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasError)
              Text(_previewError!, style: const TextStyle(color: Colors.red))
            else ...[
              _buildStatRow('Filas detectadas:', '${preview!.totalRows}'),
              _buildStatRow(
                'Filas válidas:',
                '${preview.validRows}',
                Colors.green,
              ),
              if (preview.invalidRows > 0)
                _buildStatRow(
                  'Filas con error:',
                  '${preview.invalidRows}',
                  Colors.red,
                ),
              if (preview.duplicateRowsInFile > 0)
                _buildStatRow(
                  'Duplicados en archivo:',
                  '${preview.duplicateRowsInFile}',
                  Colors.orange,
                ),
              if (preview.normalizedHeaders.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Columnas detectadas: ${preview.normalizedHeaders.join(", ")}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (preview.errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Primeras observaciones:',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...preview.errors
                    .take(5)
                    .map(
                      (error) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $error',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                if (preview.errors.length > 5)
                  Text(
                    '... y ${preview.errors.length - 5} observaciones más',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Intentar obtener bytes directamente
        Uint8List? fileBytes = file.bytes;

        // Si bytes es null, leer desde path
        if (fileBytes == null && file.path != null) {
          debugPrint('⚠️ file.bytes es null, leyendo desde path...');
          try {
            final fileFile = File(file.path!);
            if (await fileFile.exists()) {
              fileBytes = await fileFile.readAsBytes();
            }
          } catch (e) {
            debugPrint('❌ Error al leer archivo: $e');
          }
        }

        if (fileBytes == null || fileBytes.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '❌ No se pudo leer el archivo. Intenta con otro.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Detectar tipo de archivo
        String? fileType;
        final extension = file.name.split('.').last.toLowerCase();
        if (extension == 'csv') {
          fileType = 'csv';
        } else if (extension == 'xlsx' || extension == 'xls') {
          fileType = 'excel';
        }

        ImportPreviewResult? preview;
        String? previewError;
        try {
          if (fileType == 'csv') {
            preview = ImportService.previewCsv(fileBytes);
          } else if (fileType == 'excel') {
            preview = ImportService.previewExcel(fileBytes);
          } else {
            previewError = 'Tipo de archivo no soportado';
          }
        } catch (e) {
          previewError = e.toString();
        }

        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = fileBytes;
          _selectedFileType = fileType;
          _previewResult = preview;
          _previewError = previewError;
          _lastImportLog = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error seleccionando archivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareExcelTemplate() async {
    try {
      final bytes = ImportService.buildMembersImportTemplateExcel();
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'plantilla_socios.xlsx',
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Plantilla de socios',
        text:
            'Plantilla oficial para importar socios. Conserva los encabezados y completa modalidad con A, B, C, D, E, N, N1, N2, X, Y o Z.',
      );
      _showTemplateMessage('Plantilla Excel generada');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar la plantilla Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTemplateMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _importFile() async {
    if (_selectedFileBytes == null || _selectedFileType == null) return;

    final preview = _previewResult;
    if (_previewError != null || (preview != null && !preview.canImport)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Corrige el archivo antes de importar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (preview != null && preview.hasWarnings) {
      final confirmed = await _confirmImportWithWarnings(preview);
      if (!confirmed || !mounted) return;
    }

    setState(() => _isProcessing = true);

    try {
      ImportLog log;

      if (_selectedFileType == 'csv') {
        log = await _service.importFromCsv(
          fileBytes: _selectedFileBytes!,
          fileName: _selectedFileName ?? 'archivo.csv',
        );
      } else {
        log = await _service.importFromExcel(
          fileBytes: _selectedFileBytes!,
          fileName: _selectedFileName ?? 'archivo.xlsx',
        );
      }

      setState(() {
        _isProcessing = false;
        _lastImportLog = log;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              log.isSuccessful
                  ? '✅ Importación completada exitosamente'
                  : '⚠️ Importación completada con errores',
            ),
            backgroundColor: log.isSuccessful ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en importación: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<bool> _confirmImportWithWarnings(ImportPreviewResult preview) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Importar con observaciones'),
            content: Text(
              'La prevalidación encontró ${preview.invalidRows} filas con error y ${preview.duplicateRowsInFile} duplicados dentro del archivo. '
              'La importación intentará procesar sólo las filas válidas y registrará el resultado en auditoría.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Revisar archivo'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.upload_file),
                label: const Text('Importar válidas'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
