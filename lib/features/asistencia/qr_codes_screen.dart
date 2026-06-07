import 'dart:io';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/user.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/models/asistencia/persona.dart';
import '../../core/models/member.dart';
import '../../core/models/user_role.dart';
import '../../core/utils/qr_encoding_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/asistencia_service.dart';
import '../../services/members_service.dart';
import '../elections/widgets/voto_premium_chrome.dart';

/// Pantalla premium: código QR destacado + acciones masivas (PDF) + listado.
class QRCodesScreen extends StatefulWidget {
  const QRCodesScreen({super.key});

  @override
  State<QRCodesScreen> createState() => _QRCodesScreenState();
}

class _QRCodesScreenState extends State<QRCodesScreen> {
  final _service = AsistenciaService();
  final _membersService = MembersService();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final GlobalKey _primaryQrBoundaryKey = GlobalKey();
  String _searchQuery = '';
  int? _manualPrimaryIndex;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

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

  static int _pickPrimaryIndex(
    List<Map<String, dynamic>> items,
    AppUser? user,
  ) {
    if (items.isEmpty) return 0;
    final mid = user?.memberId;
    if (mid != null && mid.isNotEmpty) {
      final i = items.indexWhere(
        (e) => e['source'] == 'member' && (e['data'] as Member).id == mid,
      );
      if (i >= 0) return i;
    }
    final en = user?.employeeNumber?.trim();
    if (en != null && en.isNotEmpty) {
      var i = items.indexWhere((e) {
        if (e['source'] != 'member') return false;
        final m = e['data'] as Member;
        return m.workerCode?.trim() == en || m.memberNumber.trim() == en;
      });
      if (i >= 0) return i;
      i = items.indexWhere((e) {
        if (e['source'] != 'persona') return false;
        final p = e['data'] as PersonaAsistencia;
        return p.identificador?.trim() == en;
      });
      if (i >= 0) return i;
    }
    final act = items.indexWhere(
      (e) =>
          e['source'] == 'member' &&
          (e['data'] as Member).status == MemberStatus.active,
    );
    if (act >= 0) return act;
    return 0;
  }

  int _effectivePrimaryIndex(List<Map<String, dynamic>> items, AppUser? user) {
    if (items.isEmpty) return 0;
    final manual = _manualPrimaryIndex;
    if (manual != null && manual >= 0 && manual < items.length) {
      return manual;
    }
    return _pickPrimaryIndex(items, user);
  }

  static String _qrPayloadForItem(Map<String, dynamic> item) {
    final source = item['source'] as String;
    if (source == 'member') {
      final m = item['data'] as Member;
      return m.workerCode?.isNotEmpty == true
          ? QREncodingHelper.generateMemberQRCode(m)
          : m.id;
    }
    return QREncodingHelper.generateQRCode(item['data'] as PersonaAsistencia);
  }

  static String _nombreForItem(Map<String, dynamic> item) {
    if (item['source'] == 'member') {
      return (item['data'] as Member).fullName;
    }
    return (item['data'] as PersonaAsistencia).nombreCompleto;
  }

  static String _detailLineForItem(Map<String, dynamic> item) {
    if (item['source'] == 'member') {
      final m = item['data'] as Member;
      final s = m.memberNumber.isEmpty ? '—' : 'S-${m.memberNumber}';
      final w = m.workerCode?.isNotEmpty == true
          ? 'TRAB-${m.workerCode}'
          : 'Sin TRAB';
      return '$s • $w • ${m.status.displayName}';
    }
    final p = item['data'] as PersonaAsistencia;
    return 'Legacy • ${p.identificador ?? '—'}';
  }

  Future<void> _capturarYCompartirQr(
    GlobalKey boundaryKey,
    Map<String, dynamic> item,
  ) async {
    try {
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('No se pudo capturar el QR');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Error al generar imagen');

      final pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final slug = item['source'] == 'member'
          ? ((item['data'] as Member).workerCode ?? (item['data'] as Member).id)
          : (item['data'] as PersonaAsistencia).identificador ??
                (item['data'] as PersonaAsistencia).id;
      final safe = slug.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final filePath = '${directory.path}/qr_$safe.png';
      await File(filePath).writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text:
            'Código QR — ${_nombreForItem(item)}\n${_detailLineForItem(item)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR listo para descargar o compartir'),
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

  List<Map<String, dynamic>> _filterItemsForPdf(
    List<Map<String, dynamic>> items, {
    required bool onlyActiveMembers,
  }) {
    final out = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item['source'] == 'member') {
        final m = item['data'] as Member;
        if (onlyActiveMembers && m.status != MemberStatus.active) continue;
      }
      out.add(item);
    }
    return out;
  }

  pw.Widget _pdfCredentialRow(Map<String, dynamic> item) {
    final title = _nombreForItem(item);
    final subtitle = _detailLineForItem(item);
    final payload = _qrPayloadForItem(item);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.BarcodeWidget(
            data: payload,
            barcode: Barcode.qrCode(),
            width: 74,
            height: 74,
            drawText: false,
            color: PdfColor.fromInt(0xFF2B2265),
            backgroundColor: PdfColors.white,
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF2B2265),
                  ),
                  maxLines: 2,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  subtitle,
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCredentialsPdf(
    BuildContext context,
    List<Map<String, dynamic>> sourceItems, {
    required bool onlyActiveMembers,
  }) async {
    final filtered = _filterItemsForPdf(
      sourceItems,
      onlyActiveMembers: onlyActiveMembers,
    );
    if (filtered.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            onlyActiveMembers
                ? 'No hay socios activos para exportar.'
                : 'No hay credenciales para exportar.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );

    try {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => [
            pw.Text(
              'Credenciales de asistencia (QR)',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF2B2265),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              onlyActiveMembers
                  ? 'Ámbito: socios activos y personas legacy'
                  : 'Ámbito: todos los socios y personas legacy',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Generado: ${DateTime.now().toLocal()}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 16),
            ...filtered.map(_pdfCredentialRow),
          ],
        ),
      );

      final bytes = await doc.save();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final suffix = onlyActiveMembers ? 'activos' : 'completo';
      if (!context.mounted) return;
      Navigator.of(context).pop();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'credenciales_qr_asistencia_${suffix}_$stamp.pdf',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generado para compartir o guardar'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('❌ PDF QR: $e\n$st');
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generando PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAyudaCredenciales() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppDesignTokens.background,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Credenciales de asistencia',
                style: AppDesignTokens.titleLarge(ctx),
              ),
              const SizedBox(height: 12),
              Text(
                'El QR destacado permite descargarlo o compartirlo como imagen PNG. Las acciones masivas generan '
                'un PDF con todos los códigos del ámbito elegido.',
                style: AppDesignTokens.bodyMuted(ctx),
              ),
              const SizedBox(height: 16),
              const Text(
                '• Socios miembros (`members`): el payload sigue las reglas de QREncodingHelper.\n'
                '• Personas legacy (`personas`): JSON de nombre / apellido / identificador.\n'
                '• Eliminar personas legacy solo está disponible desde la lista inferior.',
              ),
            ],
          ),
        );
      },
    );
  }

  void _copiarPayload(Map<String, dynamic> item) {
    Clipboard.setData(ClipboardData(text: _qrPayloadForItem(item)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payload copiado al portapapeles')),
    );
  }

  Future<void> _showPersonaActions(PersonaAsistencia persona) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppDesignTokens.background,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  persona.nombreCompleto,
                  style: AppDesignTokens.titleLarge(ctx),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.copy, color: AppDesignTokens.primary),
                  title: const Text('Copiar payload del QR'),
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: QREncodingHelper.generateQRCode(persona),
                      ),
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Copiado')));
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade700,
                  ),
                  title: Text(
                    'Eliminar persona',
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Eliminar persona'),
                        content: Text(
                          '¿Eliminar a ${persona.nombreCompleto}? Esta acción no se puede deshacer.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (!mounted || confirmar != true) return;
                    try {
                      await _service.deletePersona(persona.id);
                      _manualPrimaryIndex = null;
                      setState(() {});
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${persona.nombreCompleto} eliminado'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? UserRole.user;
    final appUser = auth.user;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: VotoModuleBottomNavigation(
        role: role,
        selection: VotoNavSlot.asistencia,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Códigos QR',
            subtitle: 'Credenciales de asistencia',
            onBack: () => Navigator.pop(context),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VotoCircleIconButton(
                  icon: Icons.help_outline_rounded,
                  onTap: _showAyudaCredenciales,
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.search_rounded,
                  onTap: () =>
                      FocusScope.of(context).requestFocus(_searchFocus),
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.sync_rounded,
                  onTap: () => setState(() {}),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDesignTokens.horizontalPadding,
              8,
              AppDesignTokens.horizontalPadding,
              6,
            ),
            child: TextField(
              focusNode: _searchFocus,
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o número…',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppDesignTokens.primary.withValues(alpha: 0.65),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppDesignTokens.primary.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppDesignTokens.primary.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppDesignTokens.primary.withValues(alpha: 0.45),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onChanged: (v) {
                _manualPrimaryIndex = null;
                setState(() => _searchQuery = v);
              },
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
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snap.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppDesignTokens.primary,
                    ),
                  );
                }

                final items = snap.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 56,
                            color: AppDesignTokens.primary.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No se encontraron resultados'
                                : 'No hay personas registradas.\nVe a Importar lista u operaciones de socios.',
                            style: AppDesignTokens.bodyMuted(context),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final primaryIdx = _effectivePrimaryIndex(
                  items,
                  appUser,
                ).clamp(0, items.length - 1);
                final primary = items[primaryIdx];
                final qrData = _qrPayloadForItem(primary);
                final others = <Map<String, dynamic>>[
                  for (var i = 0; i < items.length; i++)
                    if (i != primaryIdx) items[i],
                ];

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: AppDesignTokens.horizontalPadding,
                    right: AppDesignTokens.horizontalPadding,
                    bottom: MediaQuery.paddingOf(context).bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -14),
                        child: PremiumCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                          child: Column(
                            children: [
                              Text(
                                'QR principal del socio',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppDesignTokens.primaryDark,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              RepaintBoundary(
                                key: _primaryQrBoundaryKey,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      AppDesignTokens.radiusMedium,
                                    ),
                                    border: Border.all(
                                      color: AppDesignTokens.primary.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                  ),
                                  child: QrImageView(
                                    data: qrData,
                                    size: 176,
                                    backgroundColor: Colors.white,
                                    eyeStyle: QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: AppDesignTokens.primaryDark,
                                    ),
                                    dataModuleStyle: QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: AppDesignTokens.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _nombreForItem(primary),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppDesignTokens.primaryDark,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _detailLineForItem(primary),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppDesignTokens.primaryDark
                                          .withValues(alpha: 0.55),
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      PrimaryButton(
                        label: 'Descargar QR',
                        icon: Icons.download_rounded,
                        onPressed: () => _capturarYCompartirQr(
                          _primaryQrBoundaryKey,
                          primary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Acciones masivas',
                        style: AppDesignTokens.titleLarge(context),
                      ),
                      const SizedBox(height: 12),
                      _MassActionTile(
                        title: 'Generar todos los QR',
                        subtitle: 'Crear credenciales para personas activas',
                        leadingIcon: Icons.qr_code_2_rounded,
                        leadingAccent: AppDesignTokens.lavanda,
                        trailingTint: AppDesignTokens.primary,
                        onTap: () => _exportCredentialsPdf(
                          context,
                          items,
                          onlyActiveMembers: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MassActionTile(
                        title: 'Exportar credenciales',
                        subtitle: 'Descargar PDF con códigos por persona',
                        leadingIcon: Icons.sim_card_download_rounded,
                        leadingAccent: AppDesignTokens.lavanda.withValues(
                          alpha: 0.8,
                        ),
                        trailingTint: Colors.blue.shade700,
                        onTap: () => _exportCredentialsPdf(
                          context,
                          items,
                          onlyActiveMembers: false,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (others.isNotEmpty) ...[
                        Text(
                          'Más credenciales (${others.length})',
                          style: AppDesignTokens.titleLarge(context),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ...others.map((e) {
                        final idx = items.indexOf(e);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() => _manualPrimaryIndex = idx);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE6E9EF),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppDesignTokens.lavanda,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.qr_code_rounded,
                                        color: AppDesignTokens.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _nombreForItem(e),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Color(0xFF2B2265),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _detailLineForItem(e),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _copiarPayload(e),
                                      icon: Icon(
                                        Icons.copy_rounded,
                                        size: 20,
                                        color: AppDesignTokens.primary
                                            .withValues(alpha: 0.85),
                                      ),
                                      tooltip: 'Copiar',
                                    ),
                                    if (e['source'] == 'persona')
                                      IconButton(
                                        onPressed: () => _showPersonaActions(
                                          e['data'] as PersonaAsistencia,
                                        ),
                                        icon: Icon(
                                          Icons.more_horiz_rounded,
                                          color: Colors.grey.shade600,
                                        ),
                                        tooltip: 'Más',
                                      ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila táctil de acción masiva (estilo lista premium).
class _MassActionTile extends StatelessWidget {
  const _MassActionTile({
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.leadingAccent,
    required this.trailingTint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final Color leadingAccent;
  final Color trailingTint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6E9EF)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: leadingAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(leadingIcon, color: trailingTint, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF2B2265),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 22,
                  decoration: BoxDecoration(
                    color: trailingTint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
