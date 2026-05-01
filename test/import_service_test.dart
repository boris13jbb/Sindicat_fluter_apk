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
        'numero_socio,nombres,apellidos,documento,email,telefono,worker_code',
        '1001,"Ana, María",Pérez,123,ana@example.com,555,W-1',
      ].join('\n');

      final rows = ImportService.parseCsv(Uint8List.fromList(utf8.encode(csv)));

      expect(rows, hasLength(2));
      expect(rows[1][0], '1001');
      expect(rows[1][1], 'Ana, María');
      expect(rows[1][2], 'Pérez');
      expect(rows[1][6], 'W-1');
    });
  });
}
