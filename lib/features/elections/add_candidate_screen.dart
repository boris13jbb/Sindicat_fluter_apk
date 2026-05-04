import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/user_role.dart';
import '../../core/models/candidate.dart';
import '../../providers/auth_provider.dart';
import '../../services/candidate_photo_storage_service.dart';
import '../../services/election_service.dart';
import 'widgets/voto_premium_chrome.dart';
import 'candidate_image_upload_section.dart';

class AddCandidateScreen extends StatefulWidget {
  const AddCandidateScreen({super.key, required this.electionId});

  final String electionId;

  @override
  State<AddCandidateScreen> createState() => _AddCandidateScreenState();
}

class _AddCandidateScreenState extends State<AddCandidateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _listaController = TextEditingController();
  final _cargoController = TextEditingController();
  final _orderController = TextEditingController();
  final _propuestaController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final ValueNotifier<XFile?> _stagedPick = ValueNotifier<XFile?>(null);

  bool _loading = false;

  late final String _reservedCandidateDocId;

  @override
  void initState() {
    super.initState();
    _reservedCandidateDocId = FirebaseFirestore.instance
        .collection('elections')
        .doc(widget.electionId)
        .collection('candidates')
        .doc()
        .id;
    debugPrint(
      'AddCandidateScreen: candidateDocId reservado=$_reservedCandidateDocId',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _listaController.dispose();
    _cargoController.dispose();
    _orderController.dispose();
    _propuestaController.dispose();
    _imageUrlController.dispose();
    _stagedPick.dispose();
    super.dispose();
  }

  /// Misma persistencia: un solo `description` en Firestore (sin nuevos campos).
  String? _composedDescriptionForSave() {
    final lista = _listaController.text.trim();
    final cargo = _cargoController.text.trim();
    final prop = _propuestaController.text.trim();
    if (lista.isEmpty && cargo.isEmpty && prop.isEmpty) return null;
    final b = StringBuffer();
    if (lista.isNotEmpty) {
      b.writeln('Lista / movimiento: $lista');
    }
    if (cargo.isNotEmpty) {
      b.writeln('Cargo: $cargo');
    }
    if (prop.isNotEmpty) {
      if (b.isNotEmpty) b.writeln();
      b.write(prop);
    }
    final s = b.toString().trim();
    return s.isEmpty ? null : s;
  }

  String? _orderValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return validateCandidateOrder(v);
  }

  Future<void> _submitCandidate() async {
    if (_loading) return;
    if (widget.electionId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: ID de elección no válido')),
      );
      return;
    }
    if (_formKey.currentState?.validate() != true) return;

    final staged = _stagedPick.value;
    final trimmedManualUrl = _imageUrlController.text.trim();

    debugPrint('===== GUARDAR CANDIDATO =====');
    debugPrint('modo: agregar');
    debugPrint('electionId: ${widget.electionId}');
    debugPrint('candidateId: $_reservedCandidateDocId');
    debugPrint('selectedImageFile: ${staged?.path}');
    debugPrint('manualUrl: ${_imageUrlController.text}');
    debugPrint('oldImageUrl: (nuevo candidato — no aplica)');

    setState(() => _loading = true);
    try {
      final photoService = CandidatePhotoStorage();
      String? imageUrlResolved;

      if (staged != null) {
        imageUrlResolved = await photoService.uploadCandidateImage(
          electionId: widget.electionId,
          candidateId: _reservedCandidateDocId,
          imageFile: staged,
        );
        _imageUrlController.text = imageUrlResolved;
      } else {
        imageUrlResolved =
            trimmedManualUrl.isEmpty ? null : trimmedManualUrl;
      }

      final service = ElectionService();
      await service.addCandidate(
        Candidate(
          id: _reservedCandidateDocId,
          electionId: widget.electionId,
          name: _nameController.text.trim(),
          description: _composedDescriptionForSave(),
          imageUrl: imageUrlResolved,
          order: parseCandidateOrder(_orderController.text),
        ),
      );

      if (staged != null) {
        _stagedPick.value = null;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Candidato agregado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('ERROR GUARDANDO CANDIDATO: $e');
      debugPrint('STACKTRACE: $st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al agregar candidato: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role ?? UserRole.voter;
    final mq = MediaQuery.of(context);
    final scrollBottomPad =
        24 + mq.viewPadding.bottom + mq.viewInsets.bottom + 80;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      bottomNavigationBar: VotoModuleBottomNavigation(role: role),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Agregar candidato',
            subtitle: 'Postulantes de elección',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppDesignTokens.horizontalPadding,
                14,
                AppDesignTokens.horizontalPadding,
                scrollBottomPad,
              ),
              child: Form(
                key: _formKey,
                child: PremiumCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CandidateImageUploadSection(
                        electionId: widget.electionId,
                        urlController: _imageUrlController,
                        stagedPickNotifier: _stagedPick,
                        premiumLayout: true,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: votoPremiumInputDecoration(
                          'Nombre completo *',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _listaController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: votoPremiumInputDecoration(
                          'Lista / movimiento (opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cargoController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: votoPremiumInputDecoration(
                          'Cargo (opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _orderController,
                        decoration: votoPremiumInputDecoration(
                          'Número (orden en lista, opcional)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _orderValidator,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _propuestaController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: votoPremiumInputDecoration(
                          'Propuesta (opcional)',
                        ),
                        maxLines: 4,
                        minLines: 2,
                      ),
                      const SizedBox(height: 22),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Guardando…'),
                            ],
                          ),
                        )
                      else
                        FilledButton(
                          onPressed: _submitCandidate,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppDesignTokens.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Agregar candidato',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
