import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/models/candidate.dart';
import '../core/models/election.dart';
import '../core/models/election_result.dart';
import 'dart:async';

class ElectionService {
  ElectionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Election>> getAllElections() {
    return _firestore
        .collection('elections')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Election.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<Election>> getActiveElections() {
    return _firestore
        .collection('elections')
        .where('isVisibleToVoters', isEqualTo: true)
        .snapshots()
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

  Future<String> createElection(Election election) async {
    final ref = _firestore.collection('elections').doc();
    final data = election.toMap()..['id'] = ref.id;
    await ref.set(data);
    return ref.id;
  }

  Future<void> updateElection(Election election) async {
    await _firestore.collection('elections').doc(election.id).update(election.toMap());
  }

  Future<void> deleteElection(String electionId) async {
    await _firestore.collection('elections').doc(electionId).delete();
  }

  Stream<List<Candidate>> getCandidates(String electionId) {
    return _firestore
        .collection('elections')
        .doc(electionId)
        .collection('candidates')
        .orderBy('order', descending: false)
        .snapshots()
        .map((snap) {
          // Debug logging
          debugPrint(
            'getCandidates: Retrieved ${snap.docs.length} candidates for election $electionId',
          );
          for (var doc in snap.docs) {
            debugPrint('  - Candidate: ${doc.id}, data: ${doc.data()}');
          }
          final candidates = snap.docs
              .map(
                (d) => Candidate.fromMap({
                  ...d.data(),
                  'electionId': electionId,
                }, d.id),
              )
              .toList();
          debugPrint(
            'getCandidates: Deserialized ${candidates.length} candidates: ${candidates.map((c) => c.name).join(', ')}',
          );
          return candidates;
        });
  }

  Future<void> addCandidate(Candidate candidate) async {
    try {
      debugPrint(
        'addCandidate: Starting to add candidate "${candidate.name}" to election ${candidate.electionId}',
      );
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
      debugPrint('addCandidate: Data to be saved: $data');
      await ref.set(data);
      debugPrint(
        'addCandidate: Successfully added candidate with ID: ${ref.id}',
      );
    } catch (e) {
      debugPrint('addCandidate: ERROR - $e');
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
    await _firestore.collection('elections').doc(electionId).collection('candidates').doc(candidateId).delete();
  }
}

class VoteService {
  VoteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Caché local: usuario ya votó en esta elección (bloquea al volver a entrar en la misma sesión).
  static final Map<String, Set<String>> _votedElectionsByUser = <String, Set<String>>{};

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
      return Stream.value(true).asyncExpand((_) => _firestore
          .collection('elections')
          .doc(electionId)
          .collection('votes')
          .doc(_voteId(electionId, userId))
          .snapshots()
          .map((doc) => true));
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
    final voteRef = _firestore.collection('elections').doc(electionId).collection('votes').doc(_voteId(electionId, userId));
    final candidateRef = _firestore.collection('elections').doc(electionId).collection('candidates').doc(candidateId);
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
      debugPrint('ERROR AL VOTAR: $e');
      rethrow;
    }
  }

  Future<ElectionResults?> getElectionResults(String electionId) async {
    final electionDoc = await _firestore.collection('elections').doc(electionId).get();
    if (!electionDoc.exists) return null;

    final totalVotes = (electionDoc.data()?['totalVotes'] as num?)?.toInt() ?? 0;
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

    return ElectionResults(electionId: electionId, results: results, totalVotes: totalVotes);
  }
}
