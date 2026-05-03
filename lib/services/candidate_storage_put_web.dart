import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Entorno Web: solo datos en memoria.
Future<TaskSnapshot> storagePutCandidateImage(
  Reference ref,
  String localPathIgnored,
  Uint8List bytes,
  SettableMetadata metadata,
) async {
  debugPrint(
    'CandidateStorage: web putData path=${ref.fullPath} (${bytes.length} bytes)',
  );
  final snapshot = await ref.putData(bytes, metadata);
  debugPrint(
    'CandidateStorage: putData OK (${snapshot.totalBytes} bytes)',
  );
  return snapshot;
}
