import 'package:flutter_test/flutter_test.dart';
import 'package:fluter_apk/core/models/candidate.dart';

void main() {
  group('candidate form validation', () {
    test('accepts empty or http(s) image urls', () {
      expect(validateCandidateImageUrl(null), isNull);
      expect(validateCandidateImageUrl(''), isNull);
      expect(
        validateCandidateImageUrl('https://example.com/candidato.png'),
        isNull,
      );
      expect(
        validateCandidateImageUrl('http://example.com/candidato.png'),
        isNull,
      );
    });

    test('rejects invalid image urls', () {
      expect(validateCandidateImageUrl('example.com/image.png'), isNotNull);
      expect(
        validateCandidateImageUrl('ftp://example.com/image.png'),
        isNotNull,
      );
      expect(validateCandidateImageUrl('https:///image.png'), isNotNull);
    });

    test('validates and parses non-negative integer order', () {
      expect(validateCandidateOrder(''), isNull);
      expect(validateCandidateOrder('0'), isNull);
      expect(validateCandidateOrder('12'), isNull);
      expect(validateCandidateOrder('-1'), 'El orden no puede ser negativo');
      expect(validateCandidateOrder('1.5'), 'Ingresa un número entero');

      expect(parseCandidateOrder('12'), 12);
      expect(parseCandidateOrder(''), 0);
      expect(parseCandidateOrder('abc'), 0);
    });
  });
}
