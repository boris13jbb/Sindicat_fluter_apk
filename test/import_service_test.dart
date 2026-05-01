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
  });
}
