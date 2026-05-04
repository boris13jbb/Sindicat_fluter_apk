import 'package:flutter/material.dart';

/// Tokens visuales del diseño premium (paleta, radios, sombras, espaciados).
abstract final class AppDesignTokens {
  static const Color primary = Color(0xFF6847BE);
  static const Color primaryDark = Color(0xFF2B2265);
  static const Color lavanda = Color(0xFFEEE5FF);
  static const Color background = Color(0xFFFCF9FF);
  /// Variante inferior del degradado de fondo (splash y fondos suaves).
  static const Color backgroundGradientEnd = Color(0xFFE8DEF8);

  static const double horizontalPadding = 24;
  static const double radiusMedium = 12;
  static const double radiusLarge = 20;
  static const double radiusXLarge = 28;
  static const double radiusLogo = 32;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static TextStyle titleLarge(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
          color: primaryDark,
          fontWeight: FontWeight.w700,
          height: 1.25,
        );
  }

  static TextStyle bodyMuted(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: primaryDark.withValues(alpha: 0.55),
          fontWeight: FontWeight.w400,
        );
  }
}
