import 'package:flutter/material.dart';

import '../../../core/models/user.dart';
import '../../../core/models/user_avatar_prefs.dart';

/// Resuelve qué variante ilustrada mostrar según perfil Firestore.
WelcomeAvatarVariant resolveWelcomeAvatarVariant(AppUser? user) {
  if (user == null) return WelcomeAvatarVariant.neutral;

  final url = user.avatarUrl?.trim() ?? '';
  final mode = user.avatarMode?.trim() ?? '';

  switch (mode) {
    case UserAvatarMode.defaultMale:
      return WelcomeAvatarVariant.male;
    case UserAvatarMode.defaultFemale:
      return WelcomeAvatarVariant.female;
    case UserAvatarMode.defaultNeutral:
      return WelcomeAvatarVariant.neutral;
    case UserAvatarMode.custom:
      if (url.isNotEmpty) return WelcomeAvatarVariant.custom;
      break;
    default:
      break;
  }

  if (url.isNotEmpty) {
    return WelcomeAvatarVariant.custom;
  }

  final g = (user.gender ?? '').toLowerCase().trim();
  if (g == 'male' || g == 'm' || g == 'masculino' || g == 'hombre') {
    return WelcomeAvatarVariant.male;
  }
  if (g == 'female' ||
      g == 'f' ||
      g == 'femenino' ||
      g == 'mujer' ||
      g == 'femenina') {
    return WelcomeAvatarVariant.female;
  }
  if (g == 'neutral' || g == 'n' || g == 'otro' || g == 'other') {
    return WelcomeAvatarVariant.neutral;
  }
  return WelcomeAvatarVariant.neutral;
}

enum WelcomeAvatarVariant { male, female, neutral, custom }

/// Avatar premium del dashboard: imagen personalizada o ilustración vectorial.
class DashboardWelcomeAvatar extends StatelessWidget {
  const DashboardWelcomeAvatar({
    super.key,
    required this.user,
    required this.size,
  });

  final AppUser? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final variant = resolveWelcomeAvatarVariant(user);
    final url = user?.avatarUrl?.trim() ?? '';

    if (variant == WelcomeAvatarVariant.custom && url.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: size * 0.35,
                  height: size * 0.35,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => CustomPaint(
              size: Size(size, size),
              painter: _IllustratedAvatarPainter(
                variant: WelcomeAvatarVariant.neutral,
              ),
            ),
          ),
        ),
      );
    }

    return CustomPaint(
      size: Size(size, size),
      painter: _IllustratedAvatarPainter(
        variant: variant == WelcomeAvatarVariant.custom
            ? WelcomeAvatarVariant.neutral
            : variant,
      ),
    );
  }
}

/// Ilustración estilo “premium friendly” (sin assets externos).
class _IllustratedAvatarPainter extends CustomPainter {
  _IllustratedAvatarPainter({required this.variant});

  final WelcomeAvatarVariant variant;

  static const _skin = Color(0xFFF2C4A8);
  static const _sweater = Color(0xFF6F49D8);
  static const _sweaterShadow = Color(0xFF4E2FA3);
  static const _hairDark = Color(0xFF2B2265);
  static const _hairFemale = Color(0xFF4A3D6B);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final scale = size.width / 160;

    void drawMaleHair() {
      final p = Path()
        ..addOval(Rect.fromCircle(center: Offset(cx, 46 * scale), radius: 38 * scale));
      canvas.drawPath(
        p,
        Paint()..color = _hairDark.withValues(alpha: 0.95),
      );
      canvas.drawCircle(
        Offset(cx, 52 * scale),
        34 * scale,
        Paint()..color = _skin,
      );
    }

    void drawFemaleHair() {
      final hair = Path()
        ..moveTo(cx - 46 * scale, 62 * scale)
        ..quadraticBezierTo(cx - 50 * scale, 16 * scale, cx, 10 * scale)
        ..quadraticBezierTo(cx + 50 * scale, 16 * scale, cx + 46 * scale, 62 * scale)
        ..quadraticBezierTo(cx + 36 * scale, 98 * scale, cx + 24 * scale, 104 * scale)
        ..lineTo(cx - 24 * scale, 104 * scale)
        ..quadraticBezierTo(cx - 36 * scale, 98 * scale, cx - 46 * scale, 62 * scale)
        ..close();
      canvas.drawPath(hair, Paint()..color = _hairFemale);
      canvas.drawCircle(
        Offset(cx, 56 * scale),
        29 * scale,
        Paint()..color = _skin,
      );
    }

    void drawNeutralHair() {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, 38 * scale),
            width: 58 * scale,
            height: 22 * scale,
          ),
          Radius.circular(10 * scale),
        ),
        Paint()..color = _hairDark.withValues(alpha: 0.75),
      );
      canvas.drawCircle(
        Offset(cx, 54 * scale),
        32 * scale,
        Paint()..color = _skin,
      );
    }

    switch (variant) {
      case WelcomeAvatarVariant.male:
        drawMaleHair();
        break;
      case WelcomeAvatarVariant.female:
        drawFemaleHair();
        break;
      case WelcomeAvatarVariant.neutral:
      case WelcomeAvatarVariant.custom:
        drawNeutralHair();
        break;
    }

    // Ojos
    final eyeY = variant == WelcomeAvatarVariant.female ? 52 * scale : 50 * scale;
    canvas.drawCircle(Offset(cx - 12 * scale, eyeY), 3.2 * scale, Paint()..color = _hairDark);
    canvas.drawCircle(Offset(cx + 12 * scale, eyeY), 3.2 * scale, Paint()..color = _hairDark);

    // Sonrisa
    final smile = Path()
      ..moveTo(cx - 14 * scale, 64 * scale)
      ..quadraticBezierTo(cx, 74 * scale, cx + 14 * scale, 64 * scale);
    canvas.drawPath(
      smile,
      Paint()
        ..color = _hairDark.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale
        ..strokeCap = StrokeCap.round,
    );

    // Torso / suéter
    final body = Path()
      ..moveTo(cx - 52 * scale, 88 * scale)
      ..lineTo(cx - 58 * scale, 158 * scale)
      ..lineTo(cx + 58 * scale, 158 * scale)
      ..lineTo(cx + 52 * scale, 88 * scale)
      ..close();
    canvas.drawPath(body, Paint()..color = _sweater);

    // Sombra pliegue
    final fold = Path()
      ..moveTo(cx, 92 * scale)
      ..lineTo(cx - 8 * scale, 150 * scale)
      ..lineTo(cx + 8 * scale, 150 * scale)
      ..close();
    canvas.drawPath(
      fold,
      Paint()..color = _sweaterShadow.withValues(alpha: 0.35),
    );

    // Brazos cruzados (simplificado)
    final armL = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx - 28 * scale, 118 * scale),
        width: 22 * scale,
        height: 52 * scale,
      ),
      Radius.circular(10 * scale),
    );
    final armR = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx + 28 * scale, 118 * scale),
        width: 22 * scale,
        height: 52 * scale,
      ),
      Radius.circular(10 * scale),
    );
    canvas.drawRRect(armL, Paint()..color = _sweaterShadow.withValues(alpha: 0.45));
    canvas.drawRRect(armR, Paint()..color = _sweaterShadow.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(covariant _IllustratedAvatarPainter oldDelegate) =>
      oldDelegate.variant != variant;
}
