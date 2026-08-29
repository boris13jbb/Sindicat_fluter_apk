import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:flutter/foundation.dart';
import 'package:sembast_web/sembast_web.dart';

import '../core/security/attendance_qr/secure_qr_validator.dart';

/// Cross-platform offline persistence for Secure Attendance QR V2.
///
/// Uses Sembast (IO on mobile/desktop, IndexedDB on Web). Private keys are
/// NEVER stored here — see [SecureKeyStore].
class SecureAttendanceOfflineStore {
  SecureAttendanceOfflineStore({DatabaseFactory? factory}) : _factory = factory;

  final DatabaseFactory? _factory;
  Database? _db;

  final _receipts = stringMapStoreFactory.store('receipts');
  final _challenges = stringMapStoreFactory.store('used_challenges');
  final _nonces = stringMapStoreFactory.store('used_response_nonces');
  final _sigHashes = stringMapStoreFactory.store('used_signature_hashes');
  final _packages = stringMapStoreFactory.store('packages');
  final _credentials = stringMapStoreFactory.store('credentials');
  final _events = stringMapStoreFactory.store('recent_events');
  final _meta = stringMapStoreFactory.store('meta');

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final factory =
        _factory ?? (kIsWeb ? databaseFactoryWeb : databaseFactoryIo);
    if (kIsWeb) {
      _db = await factory.openDatabase('satt2_offline.db');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'satt2_offline.db');
      _db = await factory.openDatabase(path);
    }
    return _db!;
  }

  Future<void> savePackage(Map<String, dynamic> packageJson) async {
    final db = await _open();
    final id = packageJson['packageId']?.toString() ?? 'unknown';
    await _packages.record(id).put(db, packageJson);
    await _meta.record('active_package_id').put(db, {'value': id});
  }

  Future<Map<String, dynamic>?> loadActivePackage() async {
    final db = await _open();
    final meta = await _meta.record('active_package_id').get(db);
    final id = meta?['value']?.toString();
    if (id == null) return null;
    return _packages.record(id).get(db);
  }

  Future<void> saveCredential(Map<String, dynamic> credentialJson) async {
    final db = await _open();
    final id = credentialJson['credentialId']?.toString() ?? 'default';
    await _credentials.record(id).put(db, credentialJson);
    await _meta.record('active_credential_id').put(db, {'value': id});
  }

  Future<Map<String, dynamic>?> loadActiveCredential() async {
    final db = await _open();
    final meta = await _meta.record('active_credential_id').get(db);
    final id = meta?['value']?.toString();
    if (id == null) return null;
    return _credentials.record(id).get(db);
  }

  Future<void> saveReceipt(OfflineAttendanceReceipt receipt) async {
    final db = await _open();
    await _receipts.record(receipt.localReceiptId).put(db, receipt.toMap());
    await _challenges.record(receipt.challengeId).put(db, {
      'at': receipt.scannedAtTrusted,
    });
    await _nonces.record(receipt.responseNonce).put(db, {
      'at': receipt.scannedAtTrusted,
    });
    if (receipt.memberSignature.isNotEmpty) {
      await _sigHashes.record(receipt.memberSignature).put(db, {
        'at': receipt.scannedAtTrusted,
        'eventId': receipt.eventId,
        'memberId': receipt.memberId,
      });
    }
  }

  Future<List<OfflineAttendanceReceipt>> pendingReceipts() async {
    final db = await _open();
    final rows = await _receipts.find(
      db,
      finder: Finder(
        filter: Filter.equals(
          'syncStatus',
          OfflineReceiptSyncStatus.pending.name,
        ),
      ),
    );
    return rows.map((r) => OfflineAttendanceReceipt.fromMap(r.value)).toList();
  }

  Future<List<OfflineAttendanceReceipt>> allReceiptsForEvent(
    String eventId,
  ) async {
    final db = await _open();
    final rows = await _receipts.find(
      db,
      finder: Finder(filter: Filter.equals('eventId', eventId)),
    );
    return rows.map((r) => OfflineAttendanceReceipt.fromMap(r.value)).toList();
  }

  Future<Set<String>> memberIdsRegisteredForEvent(String eventId) async {
    final all = await allReceiptsForEvent(eventId);
    return all
        .where(
          (r) =>
              r.syncStatus == OfflineReceiptSyncStatus.pending ||
              r.syncStatus == OfflineReceiptSyncStatus.syncing ||
              r.syncStatus == OfflineReceiptSyncStatus.synced,
        )
        .map((r) => r.memberId)
        .toSet();
  }

  Future<Set<String>> usedChallengeIds() async {
    final db = await _open();
    final rows = await _challenges.find(db);
    return rows.map((r) => r.key).toSet();
  }

  Future<Set<String>> usedResponseNonces() async {
    final db = await _open();
    final rows = await _nonces.find(db);
    return rows.map((r) => r.key).toSet();
  }

  Future<Set<String>> usedSignatureHashes() async {
    final db = await _open();
    final rows = await _sigHashes.find(db);
    return rows.map((r) => r.key).toSet();
  }

  /// Caches attendance events needed to generate SATT2M offline.
  Future<void> saveRecentEvents(List<Map<String, dynamic>> events) async {
    final db = await _open();
    await _events.delete(db);
    for (final e in events) {
      final id = e['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      await _events.record(id).put(db, e);
    }
  }

  Future<List<Map<String, dynamic>>> loadRecentEvents() async {
    final db = await _open();
    final rows = await _events.find(db);
    return rows.map((r) => Map<String, dynamic>.from(r.value)).toList();
  }

  Future<void> markReceiptSynced(
    String localReceiptId, {
    required OfflineReceiptSyncStatus status,
    String? rejectReason,
  }) async {
    final db = await _open();
    final existing = await _receipts.record(localReceiptId).get(db);
    if (existing == null) return;
    final updated = Map<String, dynamic>.from(existing)
      ..['syncStatus'] = status.name
      ..['rejectReason'] = rejectReason;
    await _receipts.record(localReceiptId).put(db, updated);
  }

  Future<void> saveDeviceMeta(Map<String, dynamic> meta) async {
    final db = await _open();
    await _meta.record('device').put(db, meta);
  }

  Future<Map<String, dynamic>?> loadDeviceMeta() async {
    final db = await _open();
    return _meta.record('device').get(db);
  }

  /// In-memory factory for unit tests (no disk).
  static SecureAttendanceOfflineStore memoryForTests(Database db) {
    final store = SecureAttendanceOfflineStore();
    store._db = db;
    return store;
  }

  String encodeJson(Object value) => jsonEncode(value);
}
