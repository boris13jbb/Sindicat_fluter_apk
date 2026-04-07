import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart' hide Border;
import '../core/models/member.dart';
import '../core/models/import_log.dart';
import '../core/models/audit_log.dart';
import 'audit_service.dart';

/// Resultado de validación de una fila
class RowValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, dynamic> data;

  RowValidationResult({
    required this.isValid,
    required this.errors,
    required this.data,
  });
}

/// Servicio para importación masiva de socios desde CSV/Excel
class ImportService {
  ImportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuditService? audit,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _audit = audit ?? AuditService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuditService _audit;

  /// Columnas esperadas en el CSV/Excel
  static const expectedColumns = [
    'numero_socio',
    'nombres',
    'apellidos',
    'documento',
    'email',
    'telefono',
  ];

  /// Columnas obligatorias
  static const requiredColumns = ['numero_socio', 'nombres', 'apellidos', 'documento'];

  /// Mapeo de columnas alternativas a columnas estándar
  static const Map<String, List<String>> columnMappings = {
    'numero_socio': ['numero_socio', 'codigo', 'codigo_socio', 'id', 'num_socio'],
    'nombres': ['nombres', 'nombre', 'primer_nombre', 'nombres_completos'],
    'apellidos': ['apellidos', 'apellido', 'apellidos_completos'],
    'documento': ['documento', 'cedula', 'cedula_ciudadania', 'identificacion', 'dni'],
    'email': ['email', 'correo', 'email_address', 'correo_electronico'],
    'telefono': ['telefono', 'celular', 'phone', 'movil', 'telefono_celular'],
    'departamento': ['departamento', 'depto', 'area', 'seccion'],
    'nivel': ['nivel', 'grado', 'categoria', 'cargo'],
    'mod': ['mod', 'modulo', 'modalidad'],
  };

  /// Columnas que contienen nombre completo (se separará automáticamente)
  static const fullNameColumns = ['trabajador', 'nombre_completo', 'nombre', 'fullname', 'nombre_apellido'];

  /// Columnas adicionales opcionales que se almacenan en el modelo
  static const optionalColumns = ['departamento', 'nivel', 'mod'];

  /// Normalizar headers: mapea columnas alternativas a nombres estándar
  List<String> normalizeHeaders(List<String> headers) {
    final normalized = <String>[];
    bool hasFullNameColumn = false;
    bool hasNames = false;
    bool hasLastNames = false;
    
    // Primera pasada: detectar si tenemos nombres y apellidos separados
    for (final header in headers) {
      final headerLower = header.trim().toLowerCase();
      for (final entry in columnMappings.entries) {
        if (entry.key == 'nombres' && entry.value.contains(headerLower)) {
          hasNames = true;
        }
        if (entry.key == 'apellidos' && entry.value.contains(headerLower)) {
          hasLastNames = true;
        }
      }
    }
    
    // Segunda pasada: normalizar headers
    for (final header in headers) {
      final headerLower = header.trim().toLowerCase();
      String? mappedColumn;
      
      // Buscar en el mapeo
      for (final entry in columnMappings.entries) {
        if (entry.value.contains(headerLower)) {
          mappedColumn = entry.key;
          break;
        }
      }
      
      // Si no se encontró mapeo y es una columna de nombre completo, intentar mapear
      if (mappedColumn == null && fullNameColumns.contains(headerLower)) {
        if (!hasNames && !hasLastNames) {
          // No tenemos nombres ni apellidos separados, usar esta columna para ambos
          mappedColumn = 'nombres'; // Mapear a nombres, separaremos después
          hasFullNameColumn = true;
        }
      }
      
      normalized.add(mappedColumn ?? headerLower);
    }
    
    debugPrint('📊 Headers originales: $headers');
    debugPrint('📊 Headers normalizados: $normalized');
    
    return normalized;
  }

  /// Separar nombre completo en nombres y apellidos
  Map<String, String> splitFullName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    
    if (parts.length == 1) {
      // Solo una palabra, asumir que es nombre
      return {'nombres': parts[0], 'apellidos': ''};
    } else if (parts.length == 2) {
      // Dos palabras: nombre apellido
      return {'nombres': parts[0], 'apellidos': parts[1]};
    } else {
      // Múltiples palabras: primera mitad nombres, segunda mitad apellidos
      final mid = (parts.length / 2).ceil();
      final nombres = parts.sublist(0, mid).join(' ');
      final apellidos = parts.sublist(mid).join(' ');
      return {'nombres': nombres, 'apellidos': apellidos};
    }
  }

  /// Parsear archivo CSV manualmente
  List<List<String>> parseCsv(Uint8List bytes, {String delimiter = ','}) {
    final csvString = String.fromCharCodes(bytes);
    final rows = <List<String>>[];

    // Dividir por líneas
    final lines = csvString.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      // Dividir por delimitador y limpiar
      final fields = line.split(delimiter).map((f) => f.trim()).toList();
      rows.add(fields);
    }

    return rows;
  }

  /// Validar una fila de datos
  RowValidationResult validateRow(
    List<String> row,
    List<String> headers,
    int rowIndex, {
    bool hasFullNameColumn = false,
    int fullNameIndex = -1,
  }) {
    final errors = <String>[];
    final data = <String, dynamic>{};

    // Verificar que la fila tenga suficientes columnas
    if (row.length < headers.length) {
      errors.add('Fila $rowIndex: Número insuficiente de columnas');
      return RowValidationResult(isValid: false, errors: errors, data: data);
    }

    // Mapear datos según headers
    for (var i = 0; i < headers.length; i++) {
      if (i < row.length) {
        data[headers[i]] = row[i].trim();
      }
    }

    // Si tenemos una columna de nombre completo (trabajador), separar en nombres y apellidos
    if (hasFullNameColumn && fullNameIndex >= 0 && fullNameIndex < row.length) {
      final fullName = row[fullNameIndex].trim();
      if (fullName.isNotEmpty) {
        final split = splitFullName(fullName);
        data['nombres'] = split['nombres'];
        data['apellidos'] = split['apellidos'];
        debugPrint('📝 Fila $rowIndex: Separado "$fullName" → nombres: "${split['nombres']}", apellidos: "${split['apellidos']}"');
      }
    }

    // Validar columnas obligatorias
    for (final col in requiredColumns) {
      if (!data.containsKey(col) || (data[col] as String).isEmpty) {
        errors.add('Fila $rowIndex: Columna obligatoria "$col" está vacía');
      }
    }

    // Si hay errores, retornar temprano
    if (errors.isNotEmpty) {
      return RowValidationResult(isValid: false, errors: errors, data: data);
    }

    // Validar formato de email si existe
    if (data.containsKey('email') && (data['email'] as String).isNotEmpty) {
      final email = data['email'] as String;
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(email)) {
        errors.add('Fila $rowIndex: Email no válido: $email');
      }
    }

    // Validar que numero_socio no esté vacío
    final memberNumber = data['numero_socio'] as String?;
    if (memberNumber == null || memberNumber.isEmpty) {
      errors.add('Fila $rowIndex: Número de socio es obligatorio');
    }

    return RowValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      data: data,
    );
  }

  /// Verificar duplicados en Firestore
  /// Firestore limita whereIn a máximo 30 elementos
  Future<Map<String, bool>> checkDuplicates(List<String> memberNumbers) async {
    if (memberNumbers.isEmpty) return {};

    final result = <String, bool>{};

    // Firestore tiene un límite de 30 elementos en whereIn
    const batchSize = 30;
    
    // Dividir en lotes de máximo 30 elementos
    for (int i = 0; i < memberNumbers.length; i += batchSize) {
      final end = (i + batchSize < memberNumbers.length)
          ? i + batchSize
          : memberNumbers.length;
      final batch = memberNumbers.sublist(i, end);

      debugPrint('🔍 Verificando duplicados: lote ${i ~/ batchSize + 1} (${batch.length} elementos)');

      try {
        final snapshot = await _firestore
            .collection('members')
            .where('memberNumber', whereIn: batch)
            .get();

        // Marcar cuáles ya existen
        for (final doc in snapshot.docs) {
          final memberNumber = doc.data()['memberNumber'] as String?;
          if (memberNumber != null) {
            result[memberNumber] = true;
          }
        }
      } catch (e) {
        debugPrint('❌ Error verificando duplicados en lote ${i ~/ batchSize + 1}: $e');
      }
    }

    debugPrint('✅ Duplicados encontrados: ${result.length} de ${memberNumbers.length} verificados');

    return result;
  }

  /// Importar socios desde CSV
  Future<ImportLog> importFromCsv({
    required Uint8List fileBytes,
    required String fileName,
    String delimiter = ',',
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }

    // Crear log de importación
    final logRef = _firestore.collection('import_logs').doc();
    final importLog = ImportLog.empty(userId);

    try {
      // Parsear CSV
      final rows = parseCsv(fileBytes, delimiter: delimiter);
      if (rows.isEmpty) {
        throw Exception('El archivo CSV está vacío');
      }

      // Primera fila son los headers - NORMALIZAR usando mapeo automático
      final rawHeaders = rows.first.map((h) => h.trim().toLowerCase()).toList();
      final headers = normalizeHeaders(rawHeaders);

      // Detectar si hay columna de nombre completo para separar
      bool hasFullNameColumn = false;
      int fullNameIndex = -1;
      for (int i = 0; i < rawHeaders.length; i++) {
        if (fullNameColumns.contains(rawHeaders[i])) {
          hasFullNameColumn = true;
          fullNameIndex = i;
          break;
        }
      }

      // Verificar que existan las columnas obligatorias
      for (final col in requiredColumns) {
        if (!headers.contains(col)) {
          throw Exception(
            'Columna obligatoria "$col" no encontrada en el archivo. Columnas encontradas: ${rawHeaders.join(", ")}\n\nMapeo automático aplicado: ${headers.join(", ")}\n\nSugerencia: Asegúrate de que tu archivo tenga columnas equivalentes a: ${requiredColumns.join(", ")}',
          );
        }
      }

      // Datos de las filas (sin header)
      final dataRows = rows.sublist(1);
      importLog.copyWith(totalRows: dataRows.length, fileName: fileName);

      // Validar todas las filas
      final validations = <RowValidationResult>[];
      final memberNumbers = <String>[];

      for (var i = 0; i < dataRows.length; i++) {
        final validation = validateRow(
          dataRows[i],
          headers,
          i + 2,
          hasFullNameColumn: hasFullNameColumn,
          fullNameIndex: fullNameIndex,
        ); // +2 porque empieza en fila 2
        validations.add(validation);

        if (validation.isValid) {
          final memberNumber = validation.data['numero_socio'] as String?;
          if (memberNumber != null && memberNumber.isNotEmpty) {
            memberNumbers.add(memberNumber);
          }
        }
      }

      // Verificar duplicados en Firestore
      final duplicates = await checkDuplicates(memberNumbers);

      // Procesar importaciones
      int successful = 0;
      int duplicatesCount = 0;
      int errorsCount = 0;
      final errorDetails = <String>[];
      final duplicateNumbers = <String>[];

      // Procesar en batches de 500 (límite de Firestore)
      final validRows = <Map<String, dynamic>>[];

      for (var i = 0; i < validations.length; i++) {
        final validation = validations[i];

        if (!validation.isValid) {
          errorsCount++;
          errorDetails.addAll(validation.errors);
          continue;
        }

        final memberNumber = validation.data['numero_socio'] as String?;
        if (memberNumber == null) {
          errorsCount++;
          errorDetails.add('Fila ${i + 2}: Número de socio inválido');
          continue;
        }

        // Verificar duplicado
        if (duplicates[memberNumber] == true) {
          duplicatesCount++;
          duplicateNumbers.add(memberNumber);
          errorDetails.add(
            'Fila ${i + 2}: Socio con número $memberNumber ya existe',
          );
          continue;
        }

        // Crear objeto Member con ambos campos: workerCode y documentId
        final workerCode = validation.data['workerCode'] as String?;
        final documentId = validation.data['documento'] as String?;
        
        // Validar que al menos uno de los identificadores exista
        if ((workerCode == null || workerCode.isEmpty) && 
            (documentId == null || documentId.isEmpty)) {
          errorsCount++;
          errorDetails.add('Fila ${i + 2}: Se requiere código de trabajador O cédula');
          continue;
        }
        
        final additionalData = <String, dynamic>{};
        
        // Capturar columnas opcionales si existen
        if (validation.data.containsKey('departamento') && 
            (validation.data['departamento'] as String).isNotEmpty) {
          additionalData['departamento'] = validation.data['departamento'];
        }
        if (validation.data.containsKey('nivel') && 
            (validation.data['nivel'] as String).isNotEmpty) {
          additionalData['nivel'] = validation.data['nivel'];
        }
        if (validation.data.containsKey('mod') && 
            (validation.data['mod'] as String).isNotEmpty) {
          additionalData['mod'] = validation.data['mod'];
        }

        // Generar ID único combinando workerCode y documentId
        final memberId = workerCode ?? documentId ?? DateTime.now().millisecondsSinceEpoch.toString();

        final member = Member(
          id: memberId,
          memberNumber: memberNumber,
          firstName: validation.data['nombres'] as String? ?? '',
          lastName: validation.data['apellidos'] as String? ?? '',
          fullName:
              '${validation.data['nombres'] ?? ''} ${validation.data['apellidos'] ?? ''}'
                  .trim(),
          workerCode: workerCode,
          documentId: documentId,
          email: validation.data['email'] as String?,
          phone: validation.data['telefono'] as String?,
          status: MemberStatus.active,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
          additionalData: additionalData.isNotEmpty ? additionalData : null,
        );

        validRows.add(member.toMap());

        // Si llegamos a 500, insertar batch
        if (validRows.length >= 500) {
          final batch = _firestore.batch();
          for (final row in validRows) {
            final docId = row['workerCode'] as String? ?? row['documentId'] as String? ?? '';
            final docRef = _firestore.collection('members').doc(docId);
            batch.set(docRef, row);
          }
          await batch.commit();
          successful += validRows.length;
          validRows.clear();
        }
      }

      // Insertar restantes
      if (validRows.isNotEmpty) {
        final batch = _firestore.batch();
        for (final row in validRows) {
          final docRef = _firestore.collection('members').doc();
          batch.set(docRef, row);
        }
        await batch.commit();
        successful += validRows.length;
      }

      // Guardar log de importación
      final finalLog = ImportLog(
        id: logRef.id,
        fileName: fileName,
        type: ImportType.csv,
        totalRows: dataRows.length,
        successfulImports: successful,
        duplicatesFound: duplicatesCount,
        errors: errorsCount,
        errorDetails: errorDetails.take(100).toList(), // Máx 100 errores
        duplicateMemberNumbers: duplicateNumbers.take(100).toList(),
        importedBy: userId,
        importedByName: _auth.currentUser?.displayName,
        timestamp: DateTime.now(),
      );

      await logRef.set(finalLog.toMap());

      // Registrar en auditoría
      await _audit.logAction(
        action: AuditAction.import_,
        entityType: AuditEntityType.import_,
        entityId: logRef.id,
        description:
            'Importación CSV: $fileName - $successful exitosos, $duplicatesCount duplicados, $errorsCount errores',
        platform: 'flutter',
      );

      return finalLog;
    } catch (e) {
      // Registrar error
      final errorLog = importLog.copyWith(
        errors: 1,
        errorDetails: ['Error durante importación: ${e.toString()}'],
      );

      await logRef.set(errorLog.toMap());

      // Registrar en auditoría
      await _audit.logAction(
        action: AuditAction.import_,
        entityType: AuditEntityType.import_,
        entityId: logRef.id,
        description: 'Importación CSV fallida: $fileName - ${e.toString()}',
        platform: 'flutter',
      );

      rethrow;
    }
  }

  /// Importar socios desde Excel (.xlsx, .xls)
  Future<ImportLog> importFromExcel({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }

    // Crear log de importación
    final logRef = _firestore.collection('import_logs').doc();
    final importLog = ImportLog.empty(userId);

    try {
      // Parsear Excel usando el paquete excel
      final excel = Excel.decodeBytes(fileBytes);
      
      if (excel.tables.isEmpty) {
        throw Exception('El archivo Excel no contiene hojas de cálculo');
      }

      // Obtener primera hoja
      final sheet = excel.tables.values.first;
      
      if (sheet.rows.isEmpty) {
        throw Exception('La hoja de cálculo está vacía');
      }

      // Primera fila son los headers - NORMALIZAR usando mapeo automático
      final rawHeaders = sheet.rows[0]
          .map((cell) => (cell?.value?.toString().trim().toLowerCase()) ?? '')
          .toList();
      final headers = normalizeHeaders(rawHeaders);

      debugPrint('📊 Headers detectados: $rawHeaders');
      debugPrint('📊 Headers normalizados: $headers');

      // Verificar que existan las columnas obligatorias
      for (final col in requiredColumns) {
        if (!headers.contains(col)) {
          throw Exception(
            'Columna obligatoria "$col" no encontrada en el archivo. Columnas encontradas: $rawHeaders\n\nMapeo automático aplicado: $headers\n\nSugerencia: Asegúrate de que tu archivo tenga columnas equivalentes a: ${requiredColumns.join(", ")}',
          );
        }
      }

      // Detectar si hay columna de nombre completo para separar
      bool hasFullNameColumn = false;
      int fullNameIndex = -1;
      for (int i = 0; i < rawHeaders.length; i++) {
        if (fullNameColumns.contains(rawHeaders[i])) {
          hasFullNameColumn = true;
          fullNameIndex = i;
          break;
        }
      }

      // Datos de las filas (sin header)
      final dataRows = sheet.rows.sublist(1);
      
      // Filtrar filas vacías
      final validDataRows = dataRows.where((row) {
        return row.any((cell) => cell?.value != null && cell!.value.toString().trim().isNotEmpty);
      }).toList();
      
      importLog.copyWith(totalRows: validDataRows.length, fileName: fileName);

      debugPrint('📊 Total de filas a procesar: ${validDataRows.length}');

      // Validar todas las filas
      final validations = <RowValidationResult>[];
      final memberNumbers = <String>[];

      for (var i = 0; i < validDataRows.length; i++) {
        final row = validDataRows[i];
        // Convertir celdas de Excel a lista de strings
        final stringRow = row
            .map((cell) => (cell?.value?.toString().trim()) ?? '')
            .toList();
        
        final validation = validateRow(
          stringRow,
          headers,
          i + 2,
          hasFullNameColumn: hasFullNameColumn,
          fullNameIndex: fullNameIndex,
        );
        validations.add(validation);

        if (validation.isValid) {
          final memberNumber = validation.data['numero_socio'] as String?;
          if (memberNumber != null && memberNumber.isNotEmpty) {
            memberNumbers.add(memberNumber);
          }
        }
      }

      // Verificar duplicados en Firestore
      final duplicates = await checkDuplicates(memberNumbers);

      // Procesar importaciones
      int successful = 0;
      int duplicatesCount = 0;
      int errorsCount = 0;
      final errorDetails = <String>[];
      final duplicateNumbers = <String>[];

      // Procesar en batches de 500 (límite de Firestore)
      final validRows = <Map<String, dynamic>>[];

      for (var i = 0; i < validations.length; i++) {
        final validation = validations[i];

        if (!validation.isValid) {
          errorsCount++;
          errorDetails.addAll(validation.errors);
          continue;
        }

        final memberNumber = validation.data['numero_socio'] as String?;
        if (memberNumber == null) {
          errorsCount++;
          errorDetails.add('Fila ${i + 2}: Número de socio inválido');
          continue;
        }

        // Verificar duplicado
        if (duplicates[memberNumber] == true) {
          duplicatesCount++;
          duplicateNumbers.add(memberNumber);
          errorDetails.add(
            'Fila ${i + 2}: Socio con número $memberNumber ya existe',
          );
          continue;
        }

        // Crear objeto Member
        final additionalData = <String, dynamic>{};
        
        // Capturar columnas opcionales si existen
        if (validation.data.containsKey('departamento') && 
            (validation.data['departamento'] as String).isNotEmpty) {
          additionalData['departamento'] = validation.data['departamento'];
        }
        if (validation.data.containsKey('nivel') && 
            (validation.data['nivel'] as String).isNotEmpty) {
          additionalData['nivel'] = validation.data['nivel'];
        }
        if (validation.data.containsKey('mod') && 
            (validation.data['mod'] as String).isNotEmpty) {
          additionalData['mod'] = validation.data['mod'];
        }

        final member = Member(
          id: '',
          memberNumber: memberNumber,
          firstName: validation.data['nombres'] as String? ?? '',
          lastName: validation.data['apellidos'] as String? ?? '',
          fullName:
              '${validation.data['nombres'] ?? ''} ${validation.data['apellidos'] ?? ''}'
                  .trim(),
          documentId: validation.data['documento'] as String?,
          email: validation.data['email'] as String?,
          phone: validation.data['telefono'] as String?,
          status: MemberStatus.active,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
          additionalData: additionalData.isNotEmpty ? additionalData : null,
        );

        validRows.add(member.toMap());

        // Si llegamos a 500, insertar batch
        if (validRows.length >= 500) {
          final batch = _firestore.batch();
          for (final row in validRows) {
            final docRef = _firestore.collection('members').doc();
            batch.set(docRef, row);
          }
          await batch.commit();
          successful += validRows.length;
          validRows.clear();
        }
      }

      // Insertar restantes
      if (validRows.isNotEmpty) {
        final batch = _firestore.batch();
        for (final row in validRows) {
          final docRef = _firestore.collection('members').doc();
          batch.set(docRef, row);
        }
        await batch.commit();
        successful += validRows.length;
      }

      // Guardar log de importación
      final finalLog = ImportLog(
        id: logRef.id,
        fileName: fileName,
        type: ImportType.excel,
        totalRows: validDataRows.length,
        successfulImports: successful,
        duplicatesFound: duplicatesCount,
        errors: errorsCount,
        errorDetails: errorDetails.take(100).toList(),
        duplicateMemberNumbers: duplicateNumbers.take(100).toList(),
        importedBy: userId,
        importedByName: _auth.currentUser?.displayName,
        timestamp: DateTime.now(),
      );

      await logRef.set(finalLog.toMap());

      // Registrar en auditoría
      await _audit.logAction(
        action: AuditAction.import_,
        entityType: AuditEntityType.import_,
        entityId: logRef.id,
        description:
            'Importación Excel: $fileName - $successful exitosos, $duplicatesCount duplicados, $errorsCount errores',
        platform: 'flutter',
      );

      debugPrint('✅ Importación Excel completada: $successful socios importados');

      return finalLog;
    } catch (e, stackTrace) {
      debugPrint('❌ Error en importación Excel: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Registrar error
      final errorLog = importLog.copyWith(
        errors: 1,
        errorDetails: ['Error durante importación Excel: ${e.toString()}'],
      );

      await logRef.set(errorLog.toMap());

      // Registrar en auditoría
      await _audit.logAction(
        action: AuditAction.import_,
        entityType: AuditEntityType.import_,
        entityId: logRef.id,
        description: 'Importación Excel fallida: $fileName - ${e.toString()}',
        platform: 'flutter',
      );

      rethrow;
    }
  }
}
