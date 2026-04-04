import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/models/candidate.dart';
import '../core/models/election.dart';
import '../core/models/election_result.dart';
import 'dart:async';

/// Documento de elección + si Firestore aún confirma caché o escrituras locales.
class ElectionLiveState {
  const ElectionLiveState({required this.election, required this.isSyncing});

  final Election? election;

  /// `true` si el snapshot viene solo de caché local o hay escrituras pendientes de confirmar.
  final bool isSyncing;
}

/// Lista de candidatos + estado de sincronización del snapshot de consulta.
class CandidatesLiveState {
  const CandidatesLiveState({
    required this.candidates,
    required this.isSyncing,
  });

  final List<Candidate> candidates;
  final bool isSyncing;
}

/// Datos de una lectura puntual para pintar la pantalla antes del primer `.snapshots()`.
class ResultsBootstrap {
  const ResultsBootstrap({required this.election, required this.candidates});

  final Election? election;
  final List<Candidate> candidates;
}

class ElectionService {
  ElectionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Un listener Firestore por elección; [getCandidates] reutiliza el mismo `.map()` por id.
  final Map<String, Stream<CandidatesLiveState>> _candidatesLiveCache = {};
  final Map<String, Stream<List<Candidate>>> _candidatesListCache = {};

  Stream<List<Election>> getAllElections() {
    return _firestore
        .collection('elections')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snap) =>
              snap.docs.map((d) => Election.fromMap(d.data(), d.id)).toList(),
        );
  }

  Stream<List<Election>> getActiveElections() {
    return _firestore
        .collection('elections')
        .where('isVisibleToVoters', isEqualTo: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          final now = DateTime.now().millisecondsSinceEpoch;
          return snap.docs
              .map((d) => Election.fromMap(d.data(), d.id))
              .where((e) => e.startDate <= now && e.endDate >= now)
              .toList();
        });
  }

  Future<Election?> getElection(String electionId) async {
    final doc = await _firestore.collection('elections').doc(electionId).get();
    return doc.exists ? Election.fromMap(doc.data()!, doc.id) : null;
  }

  /// Lectura puntual (documento + candidatos). Suele completar desde caché local aunque el stream tarde en el servidor.
  Future<ResultsBootstrap> loadResultsBootstrap(String electionId) async {
    final electionDoc = await _firestore
        .collection('elections')
        .doc(electionId)
        .get();
    final election = electionDoc.exists
        ? Election.fromMap(electionDoc.data()!, electionDoc.id)
        : null;
    if (election == null) {
      return const ResultsBootstrap(election: null, candidates: []);
    }
    final candSnap = await _firestore
        .collection('elections')
        .doc(electionId)
        .collection('candidates')
        .orderBy('order', descending: false)
        .get();
    final candidates = candSnap.docs
        .map(
          (d) =>
              Candidate.fromMap({...d.data(), 'electionId': electionId}, d.id),
        )
        .toList();
    return ResultsBootstrap(election: election, candidates: candidates);
  }

  /// Snapshots del documento de elección con [SnapshotMetadata] para indicadores de sync.
  Stream<ElectionLiveState> watchElectionLive(String electionId) {
    return _firestore
        .collection('elections')
        .doc(electionId)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          final m = snap.metadata;
          final syncing = m.isFromCache || m.hasPendingWrites;
          if (!snap.exists) {
            return const ElectionLiveState(election: null, isSyncing: false);
          }
          return ElectionLiveState(
            election: Election.fromMap(snap.data()!, snap.id),
            isSyncing: syncing,
          );
        });
  }

  Future<String> createElection(Election election) async {
    final ref = _firestore.collection('elections').doc();
    final data = election.toMap()..['id'] = ref.id;
    await ref.set(data);
    return ref.id;
  }

  Future<void> updateElection(Election election) async {
    await _firestore
        .collection('elections')
        .doc(election.id)
        .update(election.toMap());
  }

  Future<void> deleteElection(String electionId) async {
    await _firestore.collection('elections').doc(electionId).delete();
  }

  Stream<CandidatesLiveState> watchCandidatesLive(String electionId) {
    if (_candidatesLiveCache.containsKey(electionId)) {
      return _candidatesLiveCache[electionId]!;
    }

    try {
      final stream = _firestore
          .collection('elections')
          .doc(electionId)
          .collection('candidates')
          .orderBy('order', descending: false)
          .snapshots(includeMetadataChanges: true)
          .map((snap) {
            final syncing =
                snap.metadata.isFromCache || snap.metadata.hasPendingWrites;
            final candidates = snap.docs
                .map(
                  (d) => Candidate.fromMap({
                    ...d.data(),
                    'electionId': electionId,
                  }, d.id),
                )
                .toList();
            return CandidatesLiveState(
              candidates: candidates,
              isSyncing: syncing,
            );
          })
          .handleError((error, stackTrace) {
            debugPrint('Candidate stream error: $error');
          });

      _candidatesLiveCache[electionId] = stream;
      return stream;
    } catch (e) {
      debugPrint('Failed to create candidate stream: $e');
      rethrow;
    }
  }

  Stream<List<Candidate>> getCandidates(String electionId) {
    return _candidatesListCache.putIfAbsent(
      electionId,
      () => watchCandidatesLive(electionId).map((s) => s.candidates),
    );
  }

  Future<void> addCandidate(Candidate candidate) async {
    try {
      final ref = _firestore
          .collection('elections')
          .doc(candidate.electionId)
          .collection('candidates')
          .doc();
      final data = candidate.toMap()..['id'] = ref.id;
      // Ensure required fields are present
      data['electionId'] = candidate.electionId;
      // Ensure order field exists (default to 0 if not set)
      if (!data.containsKey('order')) {
        data['order'] = candidate.order;
      }
      await ref.set(data);
    } catch (e) {
      debugPrint('Failed to add candidate: $e');
      rethrow;
    }
  }

  Future<void> updateCandidate(Candidate candidate) async {
    await _firestore
        .collection('elections')
        .doc(candidate.electionId)
        .collection('candidates')
        .doc(candidate.id)
        .update(candidate.toMap());
  }

  Future<void> deleteCandidate(String electionId, String candidateId) async {
    await _firestore
        .collection('elections')
        .doc(electionId)
        .collection('candidates')
        .doc(candidateId)
        .delete();
  }
}

class VoteService {
  VoteService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Caché local: usuario ya votó en esta elección (bloquea al volver a entrar en la misma sesión).
  static final Map<String, Set<String>> _votedElectionsByUser =
      <String, Set<String>>{};

  static String _voteId(String electionId, String userId) =>
      '${electionId}_$userId'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

  bool hasVotedLocally(String electionId, String userId) {
    if (electionId.isEmpty || userId.isEmpty) return false;
    return _votedElectionsByUser[userId]?.contains(electionId) ?? false;
  }

  void recordLocalVote(String electionId, String userId) {
    if (electionId.isEmpty || userId.isEmpty) return;
    _votedElectionsByUser.putIfAbsent(userId, () => <String>{}).add(electionId);
  }

  Stream<bool> userVotedStream(String electionId, String userId) {
    if (electionId.isEmpty || userId.isEmpty) return Stream.value(false);
    // Si ya tenemos en caché local, emitir true de inmediato y seguir escuchando Firestore
    if (hasVotedLocally(electionId, userId)) {
      return Stream.value(true).asyncExpand(
        (_) => _firestore
            .collection('elections')
            .doc(electionId)
            .collection('votes')
            .doc(_voteId(electionId, userId))
            .snapshots()
            .map((doc) => true),
      );
    }
    return _firestore
        .collection('elections')
        .doc(electionId)
        .collection('votes')
        .doc(_voteId(electionId, userId))
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> castVote({
    required String electionId,
    required String userId,
    required String candidateId,
  }) async {
    final batch = _firestore.batch();
    final voteRef = _firestore
        .collection('elections')
        .doc(electionId)
        .collection('votes')
        .doc(_voteId(electionId, userId));
    final candidateRef = _firestore
        .collection('elections')
        .doc(electionId)
        .collection('candidates')
        .doc(candidateId);
    final electionRef = _firestore.collection('elections').doc(electionId);

    // Registrar el voto
    batch.set(voteRef, {
      'electionId': electionId,
      'userId': userId,
      'candidateId': candidateId,
      'votedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));

    // Incrementar contadores (Batch funciona offline)
    batch.update(candidateRef, {'voteCount': FieldValue.increment(1)});
    batch.update(electionRef, {
      'totalVotes': FieldValue.increment(1),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Vote casting error: $e');
      rethrow;
    }
  }

  Future<ElectionResults?> getElectionResults(String electionId) async {
    final electionDoc = await _firestore
        .collection('elections')
        .doc(electionId)
        .get();
    if (!electionDoc.exists) return null;

    final totalVotes =
        (electionDoc.data()?['totalVotes'] as num?)?.toInt() ?? 0;
    final candidatesSnap = await _firestore
        .collection('elections')
        .doc(electionId)
        .collection('candidates')
        .orderBy('voteCount', descending: true)
        .get();

    final results = candidatesSnap.docs.asMap().entries.map((entry) {
      final data = {...entry.value.data(), 'electionId': electionId};
      final c = Candidate.fromMap(data, entry.value.id);
      return ElectionResultItem(
        candidateId: c.id,
        candidateName: c.name,
        candidateImageUrl: c.imageUrl,
        voteCount: c.voteCount,
        rank: entry.key + 1,
      );
    }).toList();

    return ElectionResults(
      electionId: electionId,
      results: results,
      totalVotes: totalVotes,
    );
  }
}
