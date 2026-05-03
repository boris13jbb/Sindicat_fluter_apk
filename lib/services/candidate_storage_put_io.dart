import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Subida usando [putFile] cuando el archivo local existe (Android/iOS/desktop).
Future<TaskSnapshot> storagePutCandidateImage(
  Reference ref,
  String localPath,
  Uint8List bytes,
  SettableMetadata metadata,
) async {
  debugPrint('CandidateStorage: subiendo imagen a Storage path=${ref.fullPath}');

  if (!kIsWeb &&
      localPath.isNotEmpty &&
      !localPath.startsWith('blob:')) {
    final f = File(localPath);
    final exists = await f.exists();
    final len = exists ? await f.length() : 0;
    if (exists && len > 0) {
      final snapshot = await ref.putFile(f, metadata);
      debugPrint(
        'CandidateStorage: putFile OK (${snapshot.totalBytes} bytes reportados)',
      );
      return snapshot;
    }
    debugPrint(
      'CandidateStorage: archivo local no encontrado (${f.path}); fallback putData '
      '(${bytes.length} bytes)',
    );
  } else if (localPath.startsWith('blob:')) {
    debugPrint('CandidateStorage: ruta tipo blob → putData (${bytes.length} bytes)');
  }

  final snapshot = await ref.putData(bytes, metadata);
  debugPrint(
    'CandidateStorage: imagen subida correctamente (putData ${snapshot.totalBytes} bytes)',
  );
  return snapshot;
}
