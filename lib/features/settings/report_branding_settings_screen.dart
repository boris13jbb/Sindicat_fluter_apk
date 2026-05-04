import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/user_role.dart';
import '../../features/elections/widgets/voto_premium_chrome.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_branding_service.dart';

/// Configuración del logo que aparece en los PDF de resultados electorales.
/// Solo [UserRole.superadmin] debe acceder (ruta protegida).
class ReportBrandingSettingsScreen extends StatefulWidget {
  const ReportBrandingSettingsScreen({super.key});

  @override
  State<ReportBrandingSettingsScreen> createState() =>
      _ReportBrandingSettingsScreenState();
}

class _ReportBrandingSettingsScreenState
    extends State<ReportBrandingSettingsScreen> {
  final _service = AppBrandingService();
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.uploadAndSaveReportLogo(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo guardado. Los próximos PDF usarán esta imagen.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar logo'),
        content: const Text(
          'Los PDF volverán a mostrar el icono por defecto en cabecera y validación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.clearReportLogo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo eliminado de la configuración.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    if (role != UserRole.superadmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso restringido')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Solo el super administrador puede gestionar la marca de los reportes PDF.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Marca en reportes',
            subtitle: 'Logo para PDF de resultados',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppDesignTokens.horizontalPadding,
                16,
                AppDesignTokens.horizontalPadding,
                32,
              ),
              child: StreamBuilder(
                stream: _service.watchReportBranding(),
                builder: (context, snap) {
                  final url = snap.data?.reportLogoUrl;
                  final hasUrl = url != null && url.trim().isNotEmpty;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PremiumCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logo del reporte electoral',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignTokens.primaryDark,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'La imagen se muestra en la cabecera y en la tarjeta '
                              'de validación del PDF de resultados. '
                              'Formatos: JPG, PNG o WebP. Máximo 2 MB.',
                              style: AppDesignTokens.bodyMuted(context),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppDesignTokens.lavanda.withValues(
                                    alpha: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppDesignTokens.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: hasUrl
                                    ? Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.broken_image_outlined,
                                          size: 48,
                                          color: AppDesignTokens.primary
                                              .withValues(alpha: 0.5),
                                        ),
                                      )
                                    : Icon(
                                        Icons.image_outlined,
                                        size: 48,
                                        color: AppDesignTokens.primary
                                            .withValues(alpha: 0.45),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _pickAndUpload,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.upload_rounded),
                                label: Text(_busy ? 'Guardando…' : 'Elegir imagen'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppDesignTokens.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            if (hasUrl) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _busy ? null : _clear,
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  label: const Text('Quitar logo'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade800,
                                    side: BorderSide(
                                      color: Colors.red.shade200,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
