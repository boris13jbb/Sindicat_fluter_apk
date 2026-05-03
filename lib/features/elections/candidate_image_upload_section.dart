import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/candidate.dart';

import 'candidate_image_local_exists_io.dart' if (dart.library.html) 'candidate_image_local_exists_web.dart';

/// Campo URL de imagen + selección opcional desde galería/cámara (**sin subida inmediata**).
///
/// Solo al guardar, si [stagedPickNotifier.value] no es null, el padre debe subir imagen y
/// rellenar la URL manual en Firestore.
class CandidateImageUploadSection extends StatefulWidget {
  const CandidateImageUploadSection({
    super.key,
    required this.electionId,
    required this.urlController,
    required this.stagedPickNotifier,
  });

  final String electionId;
  final TextEditingController urlController;

  /// Foto elegida desde el picker; permanece hasta guardar o limpiar.
  final ValueNotifier<XFile?> stagedPickNotifier;

  @override
  State<CandidateImageUploadSection> createState() =>
      _CandidateImageUploadSectionState();
}

class _CandidateImageUploadSectionState
    extends State<CandidateImageUploadSection> {
  final _picker = ImagePicker();

  void _reload() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.urlController.addListener(_reload);
    widget.stagedPickNotifier.addListener(_reload);
  }

  @override
  void dispose() {
    widget.urlController.removeListener(_reload);
    widget.stagedPickNotifier.removeListener(_reload);
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (widget.electionId.isEmpty) {
      _showSnack('Error: ID de elección no válido');
      return;
    }

    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (x == null) {
        debugPrint(
          'CandidateImageUploadSection: imageFile null — no hay subida ni staging',
        );
        return;
      }

      if (!kIsWeb && x.path.trim().isNotEmpty) {
        final exists = await candidateImageLocalFileExists(x.path);
        if (!exists) {
          debugPrint(
            'CandidateImageUploadSection: el fichero seleccionado no existe: ${x.path}',
          );
          if (mounted) {
            _showSnack('El archivo seleccionado no existe o no está accesible.');
          }
          return;
        }
      }

      widget.stagedPickNotifier.value = x;
      _reload();
      _showSnack('Foto seleccionada. Se subirá al guardar el candidato.');
    } catch (e) {
      debugPrint('CandidateImageUploadSection: error al elegir imagen: $e');
      if (mounted) {
        _showSnack('No se pudo elegir la imagen: $e');
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de galería'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Tomar foto'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _clearImageAndUrl() {
    widget.urlController.clear();
    widget.stagedPickNotifier.value = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final staged = widget.stagedPickNotifier.value;
    final hasUrlText = widget.urlController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.urlController,
          decoration: const InputDecoration(
            labelText: 'URL de imagen (opcional)',
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          validator: validateCandidateImageUrl,
        ),
        const SizedBox(height: 8),
        Text(
          'Puedes escribir una URL https o elegir foto. Una URL vacía está permitida.'
          '${staged != null ? '\nHay una foto nueva seleccionada (sin subida aún).' : ''}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 8),
        if (staged != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text(
                  'Foto: ${staged.name.isEmpty ? '(archivo seleccionado)' : staged.name}',
                  overflow: TextOverflow.ellipsis,
                ),
                avatar: const Icon(Icons.image_outlined, size: 20),
                onDeleted: () {
                  widget.stagedPickNotifier.value = null;
                  setState(() {});
                },
                deleteIcon: const Icon(Icons.close),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openSourceSheet,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Elegir foto'),
              ),
            ),
            if (hasUrlText || staged != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  tooltip: 'Quitar foto nueva y URL manual',
                  onPressed: _clearImageAndUrl,
                  icon: const Icon(Icons.clear),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
