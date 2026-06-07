import 'package:flutter/material.dart';

import '../design/app_design_tokens.dart';
import '../design/widgets/app_brand_logo.dart';

/// Pantalla 01: carga inicial mientras se inicializa Firebase (solo UI premium).
class StartupLoadingScreen extends StatelessWidget {
  const StartupLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppDesignTokens.titleLarge(context).copyWith(
      fontSize: 24,
      letterSpacing: -0.3,
    );
    final subtitleStyle = AppDesignTokens.bodyMuted(context).copyWith(
      fontSize: 15,
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppDesignTokens.background,
              AppDesignTokens.backgroundGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDesignTokens.horizontalPadding,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppBrandLogo(size: 132, padding: 14),
                          const SizedBox(height: 32),
                          Text(
                            'Sistema Integrado\nSindicato',
                            textAlign: TextAlign.center,
                            style: titleStyle,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Inicializando servicios...',
                            textAlign: TextAlign.center,
                            style: subtitleStyle,
                          ),
                          const SizedBox(height: 40),
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.2,
                              color: AppDesignTokens.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
