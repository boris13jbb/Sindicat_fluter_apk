// Genera/regenera socios.xlsx en la raíz del proyecto:
// - Hoja datos: cabeceras alineadas a ImportService + ejemplo.
// - Hoja Modalidades: todos los códigos con texto "Modalidad X" para documentación.
//
// Ejecutar: dart run tool/generate_socios_template.dart

import 'dart:io';

import 'package:excel/excel.dart';
import 'package:fluter_apk/core/models/asistencia/evento.dart';

Future<void> main() async {
  final excel = Excel.createExcel();
  const datos = 'Plantilla_socios';
  final sheetDatos = excel[datos];
  excel.delete('Sheet1');

  sheetDatos.appendRow([
    TextCellValue('numero_socio'),
    TextCellValue('nombres'),
    TextCellValue('apellidos'),
    TextCellValue('worker_code'),
    TextCellValue('modalidad'),
    TextCellValue('documento'),
    TextCellValue('email'),
    TextCellValue('telefono'),
  ]);
  sheetDatos.appendRow([
    TextCellValue('1001'),
    TextCellValue('Nombre'),
    TextCellValue('Apellido'),
    TextCellValue('1001'),
    TextCellValue('A'),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
  ]);

  const refName = 'Modalidades';
  final sheetRef = excel[refName];
  sheetRef.appendRow([
    TextCellValue('codigo'),
    TextCellValue('documentar_como'),
  ]);
  for (final m in Modalidad.values) {
    sheetRef.appendRow([
      TextCellValue(m.value),
      TextCellValue(JustificacionHelper.etiquetaModalidad(m)),
    ]);
  }

  sheetDatos.setColumnWidth(0, 16);
  sheetDatos.setColumnWidth(1, 18);
  sheetDatos.setColumnWidth(2, 18);
  sheetDatos.setColumnWidth(3, 16);
  sheetDatos.setColumnWidth(4, 12);
  sheetDatos.setColumnWidth(5, 14);
  sheetDatos.setColumnWidth(6, 28);
  sheetDatos.setColumnWidth(7, 16);

  sheetRef.setColumnWidth(0, 12);
  sheetRef.setColumnWidth(1, 18);

  final bytes = excel.encode();
  if (bytes == null) {
    stderr.writeln('No se pudo codificar el Excel.');
    exit(1);
  }

  Future<void> tryWrite(String name) async {
    final f = File(name);
    await f.writeAsBytes(bytes, flush: true);
    stdout.writeln('OK: ${f.absolute.path}');
  }

  try {
    await tryWrite('socios.xlsx');
  } catch (_) {
    stderr.writeln(
      '⚠️ No se pudo escribir socios.xlsx (¿archivo abierto?). '
      'Generando socios_plantilla.xlsx.',
    );
    await tryWrite('socios_plantilla.xlsx');
  }
}
