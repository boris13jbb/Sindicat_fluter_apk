import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models/report_branding.dart';

/// Configuración de marca para PDFs (solo superadmin escribe en Firestore/Storage).
class AppBrandingService {
  AppBrandingService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String collection = 'app_settings';
  static const String brandingDocId = 'branding';
  static const int maxLogoBytes = 2 * 1024 * 1024;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection(collection).doc(brandingDocId);

  Stream<ReportBranding?> watchReportBranding() {
    return _doc.snapshots().map((s) {
      if (!s.exists || s.data() == null) return null;
      return ReportBranding.fromMap(s.data()!);
    });
  }

  Future<ReportBranding?> getReportBrandingOnce() async {
    final s = await _doc.get();
    if (!s.exists || s.data() == null) return null;
    return ReportBranding.fromMap(s.data()!);
  }

  /// Descarga bytes del logo para incrustar en el PDF (mismo bucket / URL de Storage).
  static Future<Uint8List?> loadReportLogoBytes(String? downloadUrl) async {
    final u = downloadUrl?.trim() ?? '';
    if (u.isEmpty) return null;
    try {
      final ref = FirebaseStorage.instance.refFromURL(u);
      final data = await ref.getData(maxLogoBytes);
      return data;
    } catch (e, st) {
      debugPrint('AppBrandingService: error cargando logo para PDF: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Sube una nueva imagen y actualiza la URL en Firestore. Opcionalmente borra la anterior.
  Future<void> uploadAndSaveReportLogo(XFile file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Sesión requerida');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('La imagen está vacía');
    }
    if (bytes.length > maxLogoBytes) {
      throw StateError('La imagen supera los 2 MB. Reduce tamaño o comprime.');
    }

    final previous = await getReportBrandingOnce();
    final oldUrl = previous?.reportLogoUrl;

    final ext = _extensionFor(file);
    final path = 'app_branding/report_logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref(path);
    final metadata = SettableMetadata(contentType: _mimeForExtension(ext));

    final snapshot = await ref.putData(bytes, metadata);
    final downloadUrl = await snapshot.ref.getDownloadURL();

    await _doc.set(
      <String, dynamic>{
        'reportLogoUrl': downloadUrl,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedBy': uid,
      },
      SetOptions(merge: true),
    );

    if (oldUrl != null && oldUrl.isNotEmpty && oldUrl != downloadUrl) {
      unawaited(_tryDeleteStorageByUrl(oldUrl));
    }
  }

  Future<void> clearReportLogo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Sesión requerida');
    }

    final previous = await getReportBrandingOnce();
    final oldUrl = previous?.reportLogoUrl;

    await _doc.set(
      <String, dynamic>{
        'reportLogoUrl': '',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedBy': uid,
      },
      SetOptions(merge: true),
    );

    if (oldUrl != null && oldUrl.isNotEmpty) {
      unawaited(_tryDeleteStorageByUrl(oldUrl));
    }
  }

  Future<void> _tryDeleteStorageByUrl(String url) async {
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (e) {
      debugPrint('AppBrandingService: no se pudo borrar logo anterior: $e');
    }
  }

  static String _extensionFor(XFile file) {
    final name = file.name.trim().toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      return name.substring(dot + 1);
    }
    return 'jpg';
  }

  static String _mimeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

