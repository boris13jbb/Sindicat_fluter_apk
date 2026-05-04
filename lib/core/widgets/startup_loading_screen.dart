import 'package:flutter/material.dart';

import '../design/app_design_tokens.dart';
import '../design/widgets/premium_card.dart';

/// Pantalla 01: carga inicial mientras se inicializa Firebase (solo UI premium).
class StartupLoadingScreen extends StatelessWidget {
  const StartupLoadingScreen({super.key});

  static const double _logoOuter = 132;

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
                          SizedBox(
                            width: _logoOuter,
                            height: _logoOuter,
                            child: PremiumCard(
                              margin: EdgeInsets.zero,
                              borderRadius: AppDesignTokens.radiusLogo,
                              padding: const EdgeInsets.all(18),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppDesignTokens.lavanda,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.groups_rounded,
                                    size: 52,
                                    color: AppDesignTokens.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
