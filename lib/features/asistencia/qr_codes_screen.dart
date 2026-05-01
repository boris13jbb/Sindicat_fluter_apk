import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../../core/models/asistencia/persona.dart';
import '../../core/models/member.dart';
import '../../core/utils/qr_encoding_helper.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';
import '../../services/members_service.dart';

/// Pantalla para ver códigos QR de personas
class QRCodesScreen extends StatefulWidget {
  const QRCodesScreen({super.key});

  @override
  State<QRCodesScreen> createState() => _QRCodesScreenState();
}

class _QRCodesScreenState extends State<QRCodesScreen> {
  final _service = AsistenciaService();
  final _membersService = MembersService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Códigos QR de Socios',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o número...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _buildCombinedStream(),
              builder: (context, snap) {
                if (snap.hasError) {
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

                final items = snap.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No se encontraron resultados'
                            : 'No hay personas registradas\n\nVe a "Importar desde Excel" para agregar personas',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final source = item['source'] as String;

                    if (source == 'member') {
                      return _MemberQRCard(member: item['data'] as Member);
                    } else {
                      return _PersonaQRCard(
                        persona: item['data'] as PersonaAsistencia,
                        onDelete: () => setState(() {}),
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

  /// Construye stream combinado de members + personas legacy
  Stream<List<Map<String, dynamic>>> _buildCombinedStream() {
    return _membersService.getAllMembers().asyncExpand((members) {
      return _combinarDatos(members).asStream();
    });
  }

  Future<List<Map<String, dynamic>>> _combinarDatos(
    List<Member> members,
  ) async {
    final result = <Map<String, dynamic>>[];
    final identificadoresVistos = <String>{};

    debugPrint(
      '🔄 QR Screen: Combinando ${members.length} members con personas legacy...',
    );

    try {
      // 1. Agregar Members
      for (final member in members) {
        final identificador = member.workerCode?.isNotEmpty == true
            ? member.workerCode!
            : (member.documentId ?? '');

        if (identificador.isEmpty) continue;

        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
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

      // 2. Agregar Personas legacy sin duplicados
      try {
        final personasSnapshot = await _service.firestore
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

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
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

      // Ordenar por apellido
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
        '📊 QR Screen Total: ${result.length} '
        '(${result.where((r) => r['source'] == 'member').length} members, '
        '${result.where((r) => r['source'] == 'persona').length} legacy)',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Error en _combinarDatos: $e');
      rethrow;
    }
  }
}

/// Tarjeta con código QR de un socio moderno (Member)
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
    // Generar QR de manera segura con fallback
    final qrData = widget.member.workerCode?.isNotEmpty == true
        ? QREncodingHelper.generateMemberQRCode(widget.member)
        : widget.member.id;

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
                  if (widget.member.workerCode == null ||
                      widget.member.workerCode!.isEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⚠️ Sin workerCode',
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
            Wrap(
              spacing: 4,
              children: [
                IconButton(
                  onPressed: () => _copiarDatosMiembro(context),
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copiar datos',
                  color: Colors.green,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                IconButton(
                  onPressed: () => _compartirQRMiembro(),
                  icon: const Icon(Icons.share, size: 18),
                  tooltip: 'Compartir QR',
                  color: Colors.blue,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _copiarDatosMiembro(BuildContext context) {
    final qrData = widget.member.workerCode?.isNotEmpty == true
        ? QREncodingHelper.generateMemberQRCode(widget.member)
        : widget.member.id;
    Clipboard.setData(ClipboardData(text: qrData));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Código copiado al portapapeles'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _compartirQRMiembro() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('No se pudo capturar el QR');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Error al generar imagen');

      final pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final identificador = widget.member.workerCode ?? widget.member.id;
      final filePath = '${directory.path}/qr_$identificador.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text:
            'Código QR - ${widget.member.fullName}\nN° Trabajador: $identificador',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ QR compartido'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error al compartir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

/// Tarjeta con código QR de una persona legacy
class _PersonaQRCard extends StatefulWidget {
  const _PersonaQRCard({required this.persona, required this.onDelete});

  final PersonaAsistencia persona;
  final VoidCallback onDelete;

  @override
  State<_PersonaQRCard> createState() => _PersonaQRCardState();
}

class _PersonaQRCardState extends State<_PersonaQRCard> {
  final _service = AsistenciaService();
  final _qrKey = GlobalKey();

  void _copiarDatos(BuildContext context) {
    final qrData = QREncodingHelper.generateQRCode(widget.persona);
    Clipboard.setData(ClipboardData(text: qrData));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Código copiado al portapapeles'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _compartirQR() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('No se pudo capturar el QR');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Error al generar imagen');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/qr_${widget.persona.identificador ?? widget.persona.id}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text:
            'Código QR - ${widget.persona.nombreCompleto}\nN°: ${widget.persona.identificador}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ QR compartido'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error al compartir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _eliminarPersona(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Eliminar Persona'),
        content: Text(
          '¿Estás seguro de eliminar a ${widget.persona.nombreCompleto}?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (!context.mounted || confirmar != true) return;

    try {
      await _service.deletePersona(widget.persona.id);
      if (!context.mounted) return;

      widget.onDelete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${widget.persona.nombreCompleto} eliminado'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrData = QREncodingHelper.generateQRCode(widget.persona);

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
                  Text(
                    'N°: ${widget.persona.identificador ?? 'Sin número'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => _copiarDatos(context),
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copiar datos',
                        color: Colors.green,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        onPressed: _compartirQR,
                        icon: const Icon(Icons.share, size: 18),
                        tooltip: 'Compartir QR',
                        color: Colors.blue,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _eliminarPersona(context),
                        icon: const Icon(Icons.delete, size: 18),
                        tooltip: 'Eliminar',
                        color: Colors.red,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
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
