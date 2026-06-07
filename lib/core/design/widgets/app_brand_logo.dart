import 'package:flutter/material.dart';

import '../app_design_tokens.dart';

/// Escudo oficial del sindicato (Vicunha Textil · Ecuador).
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.size = 88,
    this.padding = 10,
  });

  static const String assetPath = 'assets/images/logo_sindicato_vicunha.png';

  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.25;
    final innerRadius = size * 0.16;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      padding: EdgeInsets.all(padding),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          semanticLabel: 'Escudo Sindicato Vicunha Textil Ecuador',
          errorBuilder: (_, __, ___) => ColoredBox(
            color: AppDesignTokens.lavanda,
            child: Icon(
              Icons.groups_rounded,
              size: size * 0.45,
              color: AppDesignTokens.primary,
            ),
          ),
        ),
      ),
    );
  }
}
