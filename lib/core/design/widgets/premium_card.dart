import 'package:flutter/material.dart';

import '../app_design_tokens.dart';

/// Tarjeta blanca elevada del sistema premium.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? AppDesignTokens.radiusLarge;
    return Container(
      margin: margin ??
          const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.horizontalPadding,
            vertical: 8,
          ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
