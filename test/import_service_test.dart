import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart' hide Border;

import 'package:fluter_apk/services/import_service.dart';

void main() {
  group('ImportService column configuration', () {
    test('keeps document optional and worker_code independent', () {
      expect(ImportService.requiredColumns, [
        'numero_socio',
        'nombres',
        'apellidos',
      ]);

      expect(
        ImportService.columnMappings['numero_socio'],
        isNot(contains('worker_code')),
      );
      expect(
        ImportService.columnMappings['worker_code'],
        contains('worker_code'),
      );
    });

    test('parses quoted CSV fields with internal commas', () {
      final csv = [
        'numero_socio,nombres,apellidos,documento,email,telefono,worker_code,modalidad',
        '1001,"Ana, María",Pérez,123,ana@example.com,555,W-1,A',
      ].join('\n');

      final rows = ImportService.parseCsv(Uint8List.fromList(utf8.encode(csv)));

      expect(rows, hasLength(2));
      expect(rows[1][0], '1001');
      expect(rows[1][1], 'Ana, María');
      expect(rows[1][2], 'Pérez');
      expect(rows[1][6], 'W-1');
      expect(rows[1][7], 'A');
    });

    test('requires modalidad in row validation', () {
      final result = ImportService.validateRowStatic(
        ['1001', 'Ana', 'Perez', ''],
        ['numero_socio', 'nombres', 'apellidos', 'modalidad'],
        2,
      );

      expect(result.isValid, isFalse);
      expect(result.errors, contains('Fila 2: modalidad es obligatoria'));
    });

    test('normalizes modalidad aliases and canonical values', () {
      final headers = ImportService.normalizeHeadersStatic([
        'numero_socio',
        'nombres',
        'apellidos',
        'turno',
      ]);
      final result = ImportService.validateRowStatic(
        ['1001', 'Ana', 'Perez', 'n1'],
        headers,
        2,
      );

      expect(headers, ['numero_socio', 'nombres', 'apellidos', 'modalidad']);
      expect(result.isValid, isTrue);
      expect(result.data['modalidad'], 'N1');
    });

    test('builds a CSV template with valid canonical headers and rows', () {
      final rows = ImportService.parseCsv(
        Uint8List.fromList(
          utf8.encode(ImportService.buildMembersImportTemplateCsv()),
        ),
      );

      expect(rows, hasLength(greaterThanOrEqualTo(2)));
      expect(rows.first, ImportService.expectedColumns);

      final headers = ImportService.normalizeHeadersStatic(rows.first);
      final result = ImportService.validateRowStatic(rows[1], headers, 2);

      expect(result.isValid, isTrue);
      expect(result.data['modalidad'], 'A');
      expect(result.data['worker_code'], '37325');
    });

    test('builds an XLSX template with Socios and Modalidades sheets', () {
      final bytes = ImportService.buildMembersImportTemplateExcel();
      final excel = Excel.decodeBytes(bytes);

      expect(excel.tables.keys, contains('Socios'));
      expect(excel.tables.keys, contains('Modalidades'));

      final socios = excel.tables['Socios']!;
      final headers = socios.rows.first
          .map((cell) => cell?.value?.toString())
          .toList();

      expect(headers, ImportService.expectedColumns);
    });

    test('previews CSV rows and detects duplicates inside the file', () {
      final csv = [
        'numero_socio,nombres,apellidos,worker_code,modalidad',
        '1001,Ana,Perez,W-1,A',
        '1001,Luis,Rojas,W-2,B',
        '1003,Maria,Gomez,W-3,N1',
      ].join('\n');

      final preview = ImportService.previewCsv(
        Uint8List.fromList(utf8.encode(csv)),
      );

      expect(preview.totalRows, 3);
      expect(preview.validRows, 2);
      expect(preview.invalidRows, 0);
      expect(preview.duplicateRowsInFile, 1);
      expect(preview.hasWarnings, isTrue);
      expect(
        preview.errors,
        contains('Fila 3: Número de socio duplicado en el archivo: 1001'),
      );
    });

    test('previews CSV required header errors without importing', () {
      final csv = [
        'numero_socio,nombres,apellidos',
        '1001,Ana,Perez',
      ].join('\n');

      final preview = ImportService.previewCsv(
        Uint8List.fromList(utf8.encode(csv)),
      );

      expect(preview.canImport, isFalse);
      expect(preview.invalidRows, 1);
      expect(
        preview.errors,
        contains('Columna obligatoria "modalidad" no encontrada'),
      );
    });
  });
}
