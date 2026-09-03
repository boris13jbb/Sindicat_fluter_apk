import 'dart:convert';
import '../models/asistencia/persona.dart';
import '../models/member.dart';

/// Utilidades para generar y gestionar códigos QR de asistencia
class QREncodingHelper {
  /// Genera un código QR en formato JSON estándar para PersonaAsistencia
  /// Formato: {"nombres":"Juan","apellidos":"Pérez","identificador":"12345"}
  static String generateQRCode(PersonaAsistencia persona) {
    final qrData = {
      'nombres': persona.nombres,
      'apellidos': persona.apellidos,
      'identificador': persona.identificador ?? '',
    };
    return jsonEncode(qrData);
  }

  /// Genera un código QR LEGACY en formato JSON para Member (socio).
  ///
  /// **NO usar para Secure Attendance QR V2.** El path seguro usa SATT2
  /// (challenge/response Ed25519). Conservado solo por compatibilidad técnica
  /// (PDF admin / sync personas) hasta cutover completo.
  @Deprecated(
    'Use Secure Attendance QR V2 (SATT2). Legacy workerCode QR is not secure.',
  )
  static String generateMemberQRCode(Member member) {
    // Validar que el workerCode exista
    if (member.workerCode == null || member.workerCode!.isEmpty) {
      throw Exception(
        'No se puede generar QR: El socio no tiene Número de Trabajador (workerCode) asignado',
      );
    }

    final qrData = {
      'nombres': member.firstName,
      'apellidos': member.lastName,
      'identificador':
          member.workerCode, // SIEMPRE usar workerCode, nunca documentId
    };
    return jsonEncode(qrData);
  }

  /// Genera un código QR en formato CSV (alternativa)
  /// Formato: Juan,Pérez,12345
  static String generateQRCodeCSV(PersonaAsistencia persona) {
    return '${persona.nombres},${persona.apellidos},${persona.identificador ?? ''}';
  }

  /// Genera un código QR simple solo con identificador
  /// Formato: 12345
  static String generateQRCodeSimple(PersonaAsistencia persona) {
    return persona.identificador ?? persona.id;
  }
}
