import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/models/member.dart';

/// Excepción al consultar el padrón vía backend protegido.
class MemberLookupException implements Exception {
  MemberLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolución segura de socios del padrón sin exponer listados en cliente.
class MemberLookupService {
  MemberLookupService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static const String _lookupEndpoint =
      'https://sistema-integrado-sindicato.web.app/api/lookup-member-by-employee';

  /// Busca el socio asociado al número de trabajador del usuario autenticado.
  Future<MemberLookupResult?> lookupByEmployeeNumber(
    String employeeNumber,
  ) async {
    final value = employeeNumber.trim();
    if (value.isEmpty) return null;

    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw MemberLookupException('Sesión no válida.');
    }

    final response = await http
        .post(
          Uri.parse(_lookupEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'employeeNumber': value}),
        )
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload?['message'] as String? ??
          'No se pudo validar el número de trabajador.';
      throw MemberLookupException(message);
    }

    final memberMap = payload?['member'] as Map<String, dynamic>?;
    final memberId = payload?['memberId'] as String?;
    if (memberMap == null || memberId == null || memberId.isEmpty) {
      return null;
    }

    return MemberLookupResult(
      memberId: memberId,
      member: Member.fromMap(memberMap, memberId),
    );
  }
}

/// Resultado mínimo de la búsqueda segura de socio.
class MemberLookupResult {
  const MemberLookupResult({required this.memberId, required this.member});

  final String memberId;
  final Member member;
}
