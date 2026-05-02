import 'package:flutter_test/flutter_test.dart';
import 'package:fluter_apk/core/models/election.dart';

void main() {
  final fixedDate = DateTime(2026, 5, 1, 12);

  Election election({
    bool isActive = true,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    return Election(
      id: 'election-1',
      title: 'Elección test',
      description: 'Contrato de serialización',
      startDate: (startDate ?? now.subtract(const Duration(hours: 1)))
          .millisecondsSinceEpoch,
      endDate:
          (endDate ?? now.add(const Duration(hours: 1))).millisecondsSinceEpoch,
      isActive: isActive,
      createdBy: 'admin',
    );
  }

  group('ElectionStatus', () {
    test('serializes active elections as ACTIVE instead of DRAFT', () {
      final data = election().toMap();

      expect(data['isActive'], isTrue);
      expect(data['status'], ElectionStatus.active.firestoreValue);
    });

    test('serializes inactive elections as DRAFT', () {
      final data = election(isActive: false).toMap();

      expect(data['isActive'], isFalse);
      expect(data['status'], ElectionStatus.draft.firestoreValue);
    });

    test('serializes ended active elections as CLOSED', () {
      final data = election(
        endDate: DateTime.now().subtract(const Duration(minutes: 1)),
      ).toMap();

      expect(data['isActive'], isTrue);
      expect(data['status'], ElectionStatus.closed.firestoreValue);
    });

    test('parses stored status with a safe draft fallback', () {
      expect(
        Election.fromMap({
          'id': 'election-active',
          'title': 'Activa',
          'startDate': fixedDate.millisecondsSinceEpoch,
          'endDate': fixedDate
              .add(const Duration(days: 1))
              .millisecondsSinceEpoch,
          'isActive': true,
          'createdBy': 'admin',
          'status': 'ACTIVE',
        }).status,
        ElectionStatus.active,
      );

      expect(
        Election.fromMap({'status': 'UNKNOWN'}).status,
        ElectionStatus.draft,
      );
    });
  });

  group('validateElectionDateRange', () {
    test('requires both dates', () {
      expect(
        validateElectionDateRange(startDate: null, endDate: DateTime.now()),
        'Selecciona fechas de inicio y fin',
      );
    });

    test('rejects equal or reversed dates', () {
      final start = DateTime(2026, 5, 1, 10);

      expect(
        validateElectionDateRange(startDate: start, endDate: start),
        'La fecha de fin debe ser posterior al inicio',
      );
      expect(
        validateElectionDateRange(
          startDate: start,
          endDate: start.subtract(const Duration(minutes: 1)),
        ),
        'La fecha de fin debe ser posterior al inicio',
      );
    });

    test('requires at least one minute by default', () {
      final start = DateTime(2026, 5, 1, 10);

      expect(
        validateElectionDateRange(
          startDate: start,
          endDate: start.add(const Duration(seconds: 30)),
        ),
        'La elección debe durar al menos 1 minuto',
      );
      expect(
        validateElectionDateRange(
          startDate: start,
          endDate: start.add(const Duration(minutes: 1)),
        ),
        isNull,
      );
    });

    test('validates timestamp ranges with the same contract', () {
      final start = DateTime(2026, 5, 1, 10);

      expect(
        validateElectionTimestampRange(
          startDate: start.millisecondsSinceEpoch,
          endDate: start.add(const Duration(minutes: 2)).millisecondsSinceEpoch,
        ),
        isNull,
      );
    });
  });
}
