import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/member.dart';
import '../../core/models/asistencia/persona.dart';
import '../../core/utils/qr_encoding_helper.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/members_service.dart';
import '../../services/asistencia_service.dart';

class PersonasAsistenciaScreen extends StatefulWidget {
  const PersonasAsistenciaScreen({super.key});

  @override
  State<PersonasAsistenciaScreen> createState() =>
      _PersonasAsistenciaScreenState();
}

class _PersonasAsistenciaScreenState extends State<PersonasAsistenciaScreen> {
  final _membersService = MembersService();
  final _asistenciaService = AsistenciaService();
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Gestión de Personas',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre, cédula o código',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _buildCombinedStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  debugPrint('❌ Error en Stream combinado: ${snap.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snap.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _busqueda.isNotEmpty
                                ? 'No se encontraron resultados'
                                : 'No hay personas registradas.\n\nVe a "Importar Socios" para agregar personas desde Excel.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final item = list[i];
                    final source = item['source'] as String;

                    if (source == 'member') {
                      return _MemberQRCard(member: item['data'] as Member);
                    } else {
                      return _PersonaQRCard(
                        persona: item['data'] as PersonaAsistencia,
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _buildCombinedStream() {
    return _membersService.getAllMembers().asyncExpand((members) {
      return _combinarPersonasYMembers(members).asStream();
    });
  }

  Future<List<Map<String, dynamic>>> _combinarPersonasYMembers(
    List<Member> members,
  ) async {
    final result = <Map<String, dynamic>>[];
    final identificadoresVistos = <String>{};

    debugPrint(
      '🔄 Combinando ${members.length} members con personas legacy...',
    );

    try {
      for (final member in members) {
        final identificador = member.workerCode?.isNotEmpty == true
            ? member.workerCode!
            : (member.documentId ?? '');

        if (identificador.isEmpty) continue;

        if (_busqueda.isNotEmpty) {
          final query = _busqueda.toLowerCase();
          final matches =
              member.fullName.toLowerCase().contains(query) ||
              member.memberNumber.toLowerCase().contains(query) ||
              identificador.toLowerCase().contains(query);

          if (!matches) continue;
        }

        identificadoresVistos.add(identificador);
        result.add({'id': member.id, 'data': member, 'source': 'member'});
      }

      debugPrint('   ✅ Agregados ${result.length} members');

      try {
        final personasSnapshot = await _asistenciaService.firestore
            .collection('personas')
            .get();

        debugPrint(
          '   📊 Encontradas ${personasSnapshot.docs.length} personas legacy',
        );

        int personasAgregadas = 0;
        for (final doc in personasSnapshot.docs) {
          try {
            final persona = PersonaAsistencia.fromMap(doc.data(), doc.id);
            final identificador = persona.identificador;

            if (identificador != null &&
                identificador.isNotEmpty &&
                identificadoresVistos.contains(identificador)) {
              continue;
            }

            if (identificador != null && identificador.isNotEmpty) {
              identificadoresVistos.add(identificador);
            }

            if (_busqueda.isNotEmpty) {
              final query = _busqueda.toLowerCase();
              final matches =
                  persona.nombreCompleto.toLowerCase().contains(query) ||
                  (persona.identificador?.toLowerCase().contains(query) ??
                      false);

              if (!matches) continue;
            }

            result.add({
              'id': persona.id,
              'data': persona,
              'source': 'persona',
            });
            personasAgregadas++;
          } catch (e) {
            debugPrint('   ❌ Error procesando persona ${doc.id}: $e');
          }
        }

        debugPrint('   ✅ Agregadas $personasAgregadas personas legacy');
      } catch (e) {
        debugPrint('⚠️ Error cargando personas legacy: $e');
      }

      result.sort((a, b) {
        final sourceA = a['source'] as String;
        final sourceB = b['source'] as String;

        String nombreA, nombreB;
        if (sourceA == 'member') {
          final m = a['data'] as Member;
          nombreA = m.lastName.toLowerCase();
        } else {
          final p = a['data'] as PersonaAsistencia;
          nombreA = p.apellidos.toLowerCase();
        }

        if (sourceB == 'member') {
          final m = b['data'] as Member;
          nombreB = m.lastName.toLowerCase();
        } else {
          final p = b['data'] as PersonaAsistencia;
          nombreB = p.apellidos.toLowerCase();
        }

        return nombreA.compareTo(nombreB);
      });

      debugPrint(
        '📊 Total: ${result.length} '
        '(${result.where((r) => r['source'] == 'member').length} members, '
        '${result.where((r) => r['source'] == 'persona').length} legacy)',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Error en _combinarPersonasYMembers: $e');
      rethrow;
    }
  }
}

class _MemberQRCard extends StatefulWidget {
  const _MemberQRCard({required this.member});
  final Member member;

  @override
  State<_MemberQRCard> createState() => _MemberQRCardState();
}

class _MemberQRCardState extends State<_MemberQRCard> {
  final _qrKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // FIX CRÍTICO: Generar QR de manera segura con fallback
    final qrData = widget.member.workerCode?.isNotEmpty == true
        ? QREncodingHelper.generateMemberQRCode(widget.member)
        : widget
              .member
              .id; // Fallback: usar ID del documento si no tiene workerCode

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: qrData,
                  size: 100,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.member.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'N° Socio: ${widget.member.memberNumber}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  if (widget.member.workerCode != null &&
                      widget.member.workerCode!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Código: ${widget.member.workerCode}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  if (widget.member.documentId != null &&
                      widget.member.documentId!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Cédula: ${widget.member.documentId}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  // Advertencia visual si no tiene workerCode
                  if (widget.member.workerCode == null ||
                      widget.member.workerCode!.isEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⚠️ Sin workerCode - QR usa ID interno',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonaQRCard extends StatefulWidget {
  const _PersonaQRCard({required this.persona});
  final PersonaAsistencia persona;

  @override
  State<_PersonaQRCard> createState() => _PersonaQRCardState();
}

class _PersonaQRCardState extends State<_PersonaQRCard> {
  final _qrKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final qrData = widget.persona.identificador?.isNotEmpty == true
        ? widget.persona.identificador!
        : widget.persona.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: qrData,
                  size: 100,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.persona.nombreCompleto,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.persona.identificador != null &&
                      widget.persona.identificador!.isNotEmpty)
                    Text(
                      'ID: ${widget.persona.identificador}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  Text(
                    '(Persona Legacy)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
