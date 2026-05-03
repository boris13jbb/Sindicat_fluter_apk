import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/candidate.dart';
import '../../services/candidate_photo_storage_service.dart';
import '../../services/election_service.dart';
import '../../core/widgets/professional_app_bar.dart';
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
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _orderController = TextEditingController(text: '0');
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
    debugPrint('AddCandidateScreen: candidateDocId reservado=$_reservedCandidateDocId');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _orderController.dispose();
    _stagedPick.dispose();
    super.dispose();
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
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
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
    final mq = MediaQuery.of(context);
    final scrollBottomPad =
        24 + mq.viewPadding.bottom + mq.viewInsets.bottom;

    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Agregar Candidato',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, scrollBottomPad),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Candidato *',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              CandidateImageUploadSection(
                electionId: widget.electionId,
                urlController: _imageUrlController,
                stagedPickNotifier: _stagedPick,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _orderController,
                decoration: const InputDecoration(
                  labelText: 'Orden en lista (opcional, 0 = sin orden)',
                  prefixIcon: Icon(Icons.sort),
                ),
                keyboardType: TextInputType.number,
                validator: validateCandidateOrder,
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Guardando...'),
                    ],
                  ),
                )
              else
                FilledButton(
                  onPressed: _submitCandidate,
                  child: const Text('Agregar Candidato'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
