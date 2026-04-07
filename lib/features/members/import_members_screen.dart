import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  ImportLog? _lastImportLog;

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

            const SizedBox(height: 24),

            // Botón importar
            if (_selectedFileBytes != null)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _importFile,
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
                content: Text('❌ No se pudo leer el archivo. Intenta con otro.'),
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
        
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = fileBytes;
          _selectedFileType = fileType;
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

  Future<void> _importFile() async {
    if (_selectedFileBytes == null || _selectedFileType == null) return;

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
}
