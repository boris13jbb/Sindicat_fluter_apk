import 'package:flutter_test/flutter_test.dart';

import 'package:fluter_apk/core/models/asistencia/evento.dart';

void main() {
  group('EventoAsistencia modalidades no convocadas', () {
    test('serializes new canonical list field', () {
      final event = EventoAsistencia(
        id: 'evento-1',
        nombre: 'Asamblea',
        fecha: 1,
        tipoReunion: TipoReunion.ordinaria,
        modalidadesNoConvocadas: const [
          Modalidad.D,
          Modalidad.N1,
          Modalidad.N2,
        ],
      );

      final map = event.toMap();

      expect(map['modalidadesNoConvocadas'], ['D', 'N1', 'N2']);
      expect(map.containsKey('modalidad'), isFalse);
    });

    test('reads legacy modalidad as one excluded modalidad', () {
      final event = EventoAsistencia.fromMap({
        'nombre': 'Asamblea',
        'fecha': 1,
        'tipoReunion': 'ORDINARIA',
        'modalidad': 'D',
      }, 'evento-legacy');

      expect(event.modalidad, Modalidad.D);
      expect(event.modalidadesNoConvocadas, [Modalidad.D]);
    });

    test('ignores invalid values and avoids duplicates in list field', () {
      final event = EventoAsistencia.fromMap({
        'nombre': 'Asamblea',
        'fecha': 1,
        'tipoReunion': 'ORDINARIA',
        'modalidadesNoConvocadas': ['D', 'N1', 'D', 'NOPE'],
      }, 'evento-lista');

      expect(event.modalidadesNoConvocadas, [Modalidad.D, Modalidad.N1]);
    });
  });
}
