import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

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
  });
}
