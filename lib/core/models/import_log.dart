/// Tipo de archivo importado
enum ImportType {
  csv('CSV'),
  excel('Excel');

  const ImportType(this.displayName);

  final String displayName;

  static ImportType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'csv':
        return ImportType.csv;
      case 'excel':
      case 'xlsx':
        return ImportType.excel;
      default:
        return ImportType.csv;
    }
  }
}

/// Resultado de una importación masiva
class ImportLog {
  final String id;
  final String fileName; // Nombre del archivo importado
  final ImportType type; // Tipo de archivo
  final int totalRows; // Total de filas procesadas
  final int successfulImports; // Importaciones exitosas
  final int duplicatesFound; // Duplicados detectados
  final int errors; // Errores encontrados
  final List<String> errorDetails; // Detalles de errores
  final List<String> duplicateMemberNumbers; // Números de socios duplicados
  final String importedBy; // UID de quien importó
  final String? importedByName; // Nombre del importador
  final DateTime timestamp; // Cuándo se realizó
  final Map<String, dynamic>? metadata; // Metadatos adicionales

  ImportLog({
    required this.id,
    required this.fileName,
    required this.type,
    required this.totalRows,
    required this.successfulImports,
    required this.duplicatesFound,
    required this.errors,
    required this.errorDetails,
    required this.duplicateMemberNumbers,
    required this.importedBy,
    this.importedByName,
    required this.timestamp,
    this.metadata,
  });

  /// Crear instancia desde mapa de Firestore
  factory ImportLog.fromMap(Map<String, dynamic> map, String id) {
    return ImportLog(
      id: id,
      fileName: map['fileName'] ?? '',
      type: ImportType.fromString(map['type'] ?? 'csv'),
      totalRows: map['totalRows'] ?? 0,
      successfulImports: map['successfulImports'] ?? 0,
      duplicatesFound: map['duplicatesFound'] ?? 0,
      errors: map['errors'] ?? 0,
      errorDetails: List<String>.from(map['errorDetails'] ?? []),
      duplicateMemberNumbers: List<String>.from(
        map['duplicateMemberNumbers'] ?? [],
      ),
      importedBy: map['importedBy'] ?? '',
      importedByName: map['importedByName'],
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      metadata: map['metadata'],
    );
  }

  /// Convertir a mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'type': type.name,
      'totalRows': totalRows,
      'successfulImports': successfulImports,
      'duplicatesFound': duplicatesFound,
      'errors': errors,
      'errorDetails': errorDetails,
      'duplicateMemberNumbers': duplicateMemberNumbers,
      'importedBy': importedBy,
      if (importedByName != null) 'importedByName': importedByName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Crear log vacío para inicialización
  factory ImportLog.empty(String importerId) {
    return ImportLog(
      id: '',
      fileName: '',
      type: ImportType.csv,
      totalRows: 0,
      successfulImports: 0,
      duplicatesFound: 0,
      errors: 0,
      errorDetails: [],
      duplicateMemberNumbers: [],
      importedBy: importerId,
      timestamp: DateTime.now(),
    );
  }

  /// Porcentaje de éxito
  double get successRate {
    if (totalRows == 0) return 0;
    return successfulImports / totalRows * 100;
  }

  /// ¿La importación fue exitosa?
  bool get isSuccessful => errors == 0 && successfulImports > 0;

  /// Crear copia con cambios
  ImportLog copyWith({
    String? id,
    String? fileName,
    ImportType? type,
    int? totalRows,
    int? successfulImports,
    int? duplicatesFound,
    int? errors,
    List<String>? errorDetails,
    List<String>? duplicateMemberNumbers,
    String? importedBy,
    String? importedByName,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ImportLog(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      type: type ?? this.type,
      totalRows: totalRows ?? this.totalRows,
      successfulImports: successfulImports ?? this.successfulImports,
      duplicatesFound: duplicatesFound ?? this.duplicatesFound,
      errors: errors ?? this.errors,
      errorDetails: errorDetails ?? this.errorDetails,
      duplicateMemberNumbers:
          duplicateMemberNumbers ?? this.duplicateMemberNumbers,
      importedBy: importedBy ?? this.importedBy,
      importedByName: importedByName ?? this.importedByName,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ImportLog(id: $id, fileName: $fileName, total: $totalRows, success: $successfulImports, errors: $errors)';
  }
}
