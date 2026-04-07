import 'dart:convert';
import '../models/asistencia/persona.dart';

/// Utilidades para generar y gestionar códigos QR de asistencia
class QREncodingHelper {
  /// Genera un código QR en formato JSON estándar
  /// Formato: {"nombres":"Juan","apellidos":"Pérez","identificador":"12345"}
  static String generateQRCode(PersonaAsistencia persona) {
    final qrData = {
      'nombres': persona.nombres,
      'apellidos': persona.apellidos,
      'identificador': persona.identificador ?? '',
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
