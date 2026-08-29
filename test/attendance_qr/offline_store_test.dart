import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:fluter_apk/core/security/attendance_qr/secure_qr_validator.dart';
import 'package:fluter_apk/services/offline_attendance_store.dart';

void main() {
  test('receipt survives reopen (memory DB) and stays pending', () async {
    final factory = databaseFactoryMemory;
    final db = await factory.openDatabase('satt2_test.db');
    final store = SecureAttendanceOfflineStore.memoryForTests(db);

    final receipt = OfflineAttendanceReceipt(
      localReceiptId: 'evt_m1_nonce',
      eventId: 'evt',
      memberId: 'm1',
      memberDeviceId: 'd1',
      scannerId: 's1',
      challengeId: 'c1',
      challengeNonce: 'n1',
      responseNonce: 'rn1',
      memberSignature: 'msig',
      scannerSignature: 'ssig',
      packageId: 'p1',
      scannedAtTrusted: 1000,
      scannedAtDevice: 1001,
      syncStatus: OfflineReceiptSyncStatus.pending,
      createdAtLocal: 1002,
    );

    await store.saveReceipt(receipt);

    // Simulate "reopen" by wrapping same DB again.
    final store2 = SecureAttendanceOfflineStore.memoryForTests(db);
    final pending = await store2.pendingReceipts();
    expect(pending.length, 1);
    expect(pending.first.localReceiptId, 'evt_m1_nonce');
    expect(pending.first.syncStatus, OfflineReceiptSyncStatus.pending);

    final members = await store2.memberIdsRegisteredForEvent('evt');
    expect(members, contains('m1'));

    final used = await store2.usedChallengeIds();
    expect(used, contains('c1'));
  });
}
