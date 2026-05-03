import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'candidate_storage_put_io.dart' if (dart.library.html) 'candidate_storage_put_web.dart';

/// Subida de foto de candidato bajo
/// `elections/{electionId}/candidates/{candidateId}/{fileName}` y borrado no
/// bloqueante de la imagen anterior.
///
/// Orden obligatorio: `putFile`/`putData` → `await snapshot` →
/// `await snapshot.ref.getDownloadURL()` (nunca `ref.getDownloadURL()` antes de subir).
class CandidatePhotoStorage {
  CandidatePhotoStorage({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  static const int maxBytes = 5 * 1024 * 1024;

  /// Borrado best-effort; [object-not-found] u otros errores no deben bloquear el guardado.
  static Future<void> tryDeleteOldCandidateImage(String? oldImageUrl) async {
    try {
      final u = oldImageUrl?.trim() ?? '';
      if (u.isNotEmpty && u.startsWith('https://')) {
        debugPrint(
          'CandidatePhotoStorage: intento borrar imagen anterior (refFromURL)',
        );
        await FirebaseStorage.instance.refFromURL(u).delete();
        debugPrint('CandidatePhotoStorage: imagen anterior eliminada.');
      }
    } catch (e, st) {
      debugPrint(
        'No se pudo borrar la imagen anterior. Se continúa guardando: $e',
      );
      debugPrint('STACKTRACE: $st');
    }
  }

  /// Sube el archivo y solo entonces obtiene la URL de descarga en la **misma** ref.
  Future<String> uploadCandidateImage({
    required String electionId,
    required String candidateId,
    required XFile imageFile,
  }) async {
    if (electionId.isEmpty || candidateId.isEmpty) {
      throw StateError('ID de elección o candidato no válido');
    }

    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError(
        'Debes tener sesión iniciada para subir la foto del candidato.',
      );
    }

    final bytes = await imageFile.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('La imagen no tiene datos válidos.');
    }
    if (bytes.length > maxBytes) {
      throw StateError('La imagen supera los 5 MB. Elige otra más pequeña.');
    }

    final ext = _extensionFor(imageFile);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeCandidateId =
        candidateId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final fileName = 'candidate_${safeCandidateId}_$timestamp.$ext';

    final ref = _storage
        .ref()
        .child('elections')
        .child(electionId)
        .child('candidates')
        .child(candidateId)
        .child(fileName);

    final metadata = SettableMetadata(contentType: _mimeForExtension(ext));

    debugPrint('Subiendo imagen a: ${ref.fullPath}');

    late final TaskSnapshot snapshot;
    try {
      snapshot = await storagePutCandidateImage(
        ref,
        imageFile.path,
        bytes,
        metadata,
      );
    } on FirebaseException catch (e) {
      debugPrint('CandidatePhotoStorage: error en subida ${e.code} $e');
      rethrow;
    }

    final downloadUrl = await snapshot.ref.getDownloadURL();

    debugPrint('Imagen subida correctamente: $downloadUrl');

    return downloadUrl;
  }

  /// Compatibilidad con código que aún usa el nombre anterior.
  Future<String> uploadCandidatePhoto({
    required String electionId,
    required String candidateDocumentId,
    required XFile file,
  }) {
    return uploadCandidateImage(
      electionId: electionId,
      candidateId: candidateDocumentId,
      imageFile: file,
    );
  }

  static String _extensionFor(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (mime != null && mime.startsWith('image/')) {
      switch (mime) {
        case 'image/png':
          return 'png';
        case 'image/gif':
          return 'gif';
        case 'image/webp':
          return 'webp';
        case 'image/jpeg':
        case 'image/jpg':
          return 'jpg';
        default:
          break;
      }
    }
    var ext = p.extension(file.path).toLowerCase();
    if (ext.isEmpty || ext == '.') {
      ext = p.extension(file.name).toLowerCase();
    }
    ext = ext.replaceFirst('.', '');
    const allowed = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    if (allowed.contains(ext)) {
      return ext == 'jpeg' ? 'jpg' : ext;
    }
    return 'jpg';
  }

  static String _mimeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
