import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../elections/widgets/voto_premium_chrome.dart';

/// Pantalla de éxito tras registrar asistencia (mock `14_asistencia_confirmada`).
///
/// Pulse [Navigator.pop] con «Continuar escaneando» para volver al escáner o al
/// flujo previo sobre la misma pila del [Navigator].
class AsistenciaConfirmadaScreen extends StatelessWidget {
  const AsistenciaConfirmadaScreen({super.key});

  void _sheetInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registro aplicado',
                  style: AppDesignTokens.titleLarge(ctx),
                ),
                const SizedBox(height: 10),
                Text(
                  'Este aviso sólo informa que el sistema aceptó el registro. '
                  'Si estabas usando la cámara, puedes cerrar esta pantalla y '
                  'volverá el escaneo continuo cuando termine la pausa de '
                  'seguridad.',
                  style: AppDesignTokens.bodyMuted(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? UserRole.user;

    final greenMuted = Colors.green.withValues(alpha: 0.12);
    final greenAccent = Colors.green.shade700;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      bottomNavigationBar: VotoModuleBottomNavigation(
        role: role,
        selection: VotoNavSlot.asistencia,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: 'Asistencia registrada',
            subtitle: 'Proceso completado',
            onBack: () => Navigator.maybePop(context),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VotoCircleIconButton(
                  icon: Icons.auto_awesome_outlined,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Registro completado sin incidencias'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.info_outline_rounded,
                  onTap: () => _sheetInfo(context),
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sin alertas en este momento'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDesignTokens.horizontalPadding,
                    8,
                    AppDesignTokens.horizontalPadding,
                    24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 16,
                    ),
                    child: Column(
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -10),
                          child: PremiumCard(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.fromLTRB(26, 32, 26, 40),
                            child: Column(
                              children: [
                                Container(
                                  width: 112,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    color: greenMuted,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 58,
                                    color: greenAccent,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  '¡Registro confirmado!',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppDesignTokens.primaryDark,
                                        height: 1.25,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'La asistencia fue registrada correctamente.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.grey.shade700,
                                        height: 1.35,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: PrimaryButton(
                              label: 'Continuar escaneando',
                              icon: Icons.qr_code_scanner_rounded,
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                        ),
                      ],
                    ),
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
