import 'package:flutter/material.dart';

import '../../../core/design/app_design_tokens.dart';
import '../../../core/models/user_role.dart';

/// Cabecera ondulada morada reutilizable en el flujo `/voto/*`.
class VotoWaveHeader extends StatelessWidget {
  const VotoWaveHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _VotoWaveClipper(),
      child: Container(
        height: 168,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppDesignTokens.primaryDark,
              AppDesignTokens.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VotoCircleIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VotoCircleIconButton extends StatelessWidget {
  const VotoCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: CircleBorder(
        side: BorderSide(
          color: AppDesignTokens.primary.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppDesignTokens.primary, size: 22),
        ),
      ),
    );
  }
}

class _VotoWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 42)
      ..cubicTo(
        size.width * 0.22,
        size.height - 12,
        size.width * 0.64,
        size.height - 88,
        size.width,
        size.height - 36,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Ítem resaltado en [VotoModuleBottomNavigation] (según pantalla del flujo `/voto/*`).
enum VotoNavSlot { inicio, voto, asistencia, socios, perfil }

/// Barra inferior del módulo Voto.
class VotoModuleBottomNavigation extends StatelessWidget {
  const VotoModuleBottomNavigation({
    super.key,
    required this.role,
    this.selection = VotoNavSlot.voto,
  });

  final UserRole role;
  final VotoNavSlot selection;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin || role == UserRole.superadmin;
    final canManageAttendance =
        isAdmin || role == UserRole.operadorAsistencia;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFECE5F6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14271B5E),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            VotoNavItem(
              label: 'Inicio',
              icon: Icons.home_outlined,
              selected: selection == VotoNavSlot.inicio,
              onTap: selection == VotoNavSlot.inicio
                  ? null
                  : () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                      );
                    },
            ),
            VotoNavItem(
              label: 'Voto',
              icon: Icons.how_to_vote_outlined,
              selected: selection == VotoNavSlot.voto,
              onTap: selection == VotoNavSlot.voto
                  ? null
                  : () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/voto/elections',
                        (route) => false,
                      );
                    },
            ),
            if (canManageAttendance)
              VotoNavItem(
                label: 'Asist.',
                icon: Icons.check_rounded,
                selected: selection == VotoNavSlot.asistencia,
                onTap: selection == VotoNavSlot.asistencia
                    ? null
                    : () => Navigator.pushNamed(context, '/asistencia'),
              ),
            if (isAdmin)
              VotoNavItem(
                label: 'Socios',
                icon: Icons.groups_rounded,
                selected: selection == VotoNavSlot.socios,
                onTap: selection == VotoNavSlot.socios
                    ? null
                    : () => Navigator.pushNamed(context, '/members'),
              ),
            VotoNavItem(
              label: 'Perfil',
              icon: Icons.person_outline_rounded,
              selected: selection == VotoNavSlot.perfil,
              onTap: selection == VotoNavSlot.perfil
                  ? null
                  : () => Navigator.pushNamed(context, '/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class VotoNavItem extends StatelessWidget {
  const VotoNavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppDesignTokens.primary : const Color(0xFF6D6E8D);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 46),
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 10 : 4,
              vertical: 6,
            ),
            decoration: selected
                ? BoxDecoration(
                    color: AppDesignTokens.lavanda,
                    borderRadius: BorderRadius.circular(22),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fg, size: 18),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: fg,
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration votoPremiumInputDecoration(String label) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: AppDesignTokens.primary.withValues(alpha: 0.14),
    ),
  );
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppDesignTokens.primary, width: 1.6),
    ),
    contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
  );
}
