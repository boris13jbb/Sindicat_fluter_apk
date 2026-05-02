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

    test('rejects candidate deletion when votes exist', () {
      expect(validateCandidateDeletion(voteCount: 0), isNull);
      expect(
        validateCandidateDeletion(voteCount: 1),
        candidateWithVotesDeletionError,
      );
      expect(
        validateCandidateDeletion(voteCount: 0, hasVoteDocuments: true),
        candidateWithVotesDeletionError,
      );
    });

    test('normalizes candidate names for duplicate detection', () {
      expect(candidateNameKey('  Ana   Pérez  '), 'ana pérez');
    });

    test('detects duplicate candidate names inside the same election', () {
      const existing = Candidate(
        id: 'candidate-1',
        electionId: 'election-1',
        name: 'Ana Pérez',
      );

      expect(
        hasCandidateNameConflict(
          candidate: const Candidate(
            id: '',
            electionId: 'election-1',
            name: ' ana   pérez ',
          ),
          existingCandidates: [existing],
        ),
        isTrue,
      );

      expect(
        hasCandidateNameConflict(
          candidate: const Candidate(
            id: 'candidate-1',
            electionId: 'election-1',
            name: 'Ana Pérez',
          ),
          existingCandidates: [existing],
        ),
        isFalse,
      );

      expect(
        hasCandidateNameConflict(
          candidate: const Candidate(
            id: '',
            electionId: 'election-2',
            name: 'Ana Pérez',
          ),
          existingCandidates: [existing],
        ),
        isFalse,
      );
    });
  });
}
