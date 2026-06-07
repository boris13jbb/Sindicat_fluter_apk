import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../elections/widgets/voto_premium_chrome.dart';

/// Pantalla de acceso denegado al flujo de asistencia (mock `16_asistencia_acceso_restringido`).
class AsistenciaAccesoRestringidoScreen extends StatelessWidget {
  const AsistenciaAccesoRestringidoScreen({super.key});

  void _infoRol(BuildContext context) {
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
                  'Quién puede operar asistencia',
                  style: AppDesignTokens.titleLarge(ctx),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sólo administradores, superadministradores y el rol '
                  'operador de asistencia pueden abrir este módulo. Si tu '
                  'usuario debería tenerlo, contacta a un administrador del '
                  'sindicato.',
                  style: AppDesignTokens.bodyMuted(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _volverInicio(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? UserRole.user;

    final rosa = const Color(0xFFFFE4E6);
    final rojo = const Color(0xFFE53935);

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
            title: 'Acceso restringido',
            subtitle: 'Permisos insuficientes',
            onBack: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).maybePop();
              } else {
                _volverInicio(context);
              }
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VotoCircleIconButton(
                  icon: Icons.shield_outlined,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Módulo protegido por rol en el servidor',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.info_outline_rounded,
                  onTap: () => _infoRol(context),
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.home_outlined,
                  onTap: () => _volverInicio(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDesignTokens.horizontalPadding,
                  24,
                  AppDesignTokens.horizontalPadding,
                  32,
                ),
                child: PremiumCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: rosa,
                          child: Text(
                            '!',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: rojo,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'No tienes permisos',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppDesignTokens.primaryDark,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tu rol actual no permite acceder a esta función '
                        'de asistencia.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppDesignTokens.primaryDark.withValues(
                            alpha: 0.62,
                          ),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: 'Volver al inicio',
                        icon: Icons.home_rounded,
                        onPressed: () => _volverInicio(context),
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
