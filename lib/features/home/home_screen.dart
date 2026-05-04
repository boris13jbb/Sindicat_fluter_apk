import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/user.dart';
import '../../core/models/user_avatar_prefs.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import 'widgets/dashboard_welcome_avatar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _primary = Color(0xFF6F49D8);
  static const _primaryDark = Color(0xFF332169);
  static const _ink = Color(0xFF141632);
  static const _muted = Color(0xFF6D6E8D);
  static const _surface = Color(0xFFFEFBFF);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        final user = auth.user;
        final role = user?.role ?? UserRole.user;
        final modules = _modulesForRole(role, context);

        return Scaffold(
          backgroundColor: _surface,
          bottomNavigationBar: _BottomHomeNavigation(role: role),
          body: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const _Header(),
                      Transform.translate(
                        offset: const Offset(0, -28),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 940),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _WelcomeCard(
                                    user: user,
                                    userName: _displayName(user),
                                    roleName: role.displayName,
                                  ),
                                  const SizedBox(height: 26),
                                  Text(
                                    'Accesos principales',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: const Color(0xFF34335F),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 18),
                                  _ModuleGrid(modules: modules),
                                  const SizedBox(height: 24),
                                  const _SecurityNotice(),
                                  const SizedBox(height: 108),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _displayName(dynamic user) {
    final raw = (user?.displayName as String?)?.trim();
    final fallback = (user?.email as String?)?.trim() ?? 'Usuario';
    final name = raw?.isNotEmpty == true ? raw! : fallback;
    return _titleCaseIfNeeded(name);
  }

  static String _titleCaseIfNeeded(String value) {
    final letters = value.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]'), '');
    if (letters.isEmpty || value != value.toUpperCase()) return value;
    return value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        })
        .join(' ');
  }

  static List<_HomeModule> _modulesForRole(
    UserRole role,
    BuildContext context,
  ) {
    final isAdmin = role == UserRole.admin || role == UserRole.superadmin;
    final canManageAttendance = isAdmin || role == UserRole.operadorAsistencia;

    return [
      _HomeModule(
        title: 'Sistema de Voto',
        subtitle: 'Gestionar elecciones\ny votaciones',
        icon: Icons.how_to_vote_rounded,
        onTap: () => Navigator.pushNamed(context, '/voto/elections'),
      ),
      if (canManageAttendance)
        _HomeModule(
          title: 'Sistema de Asistencia',
          subtitle: 'Control de asistencia\na eventos',
          icon: Icons.how_to_reg_rounded,
          onTap: () => Navigator.pushNamed(context, '/asistencia'),
        ),
      if (isAdmin)
        _HomeModule(
          title: 'Gestión de Socios',
          subtitle: 'Administrar socios e\nimportación masiva',
          icon: Icons.groups_rounded,
          onTap: () => Navigator.pushNamed(context, '/members'),
        ),
      if (isAdmin)
        _HomeModule(
          title: 'Registro de Auditoría',
          subtitle: 'Ver logs de acciones\ndel sistema',
          icon: Icons.history_rounded,
          onTap: () => Navigator.pushNamed(context, '/audit/logs'),
        ),
      if (role == UserRole.superadmin)
        _HomeModule(
          title: 'Marca en reportes',
          subtitle: 'Logo en PDF de\nresultados electorales',
          icon: Icons.picture_as_pdf_outlined,
          onTap: () =>
              Navigator.pushNamed(context, '/settings/report_branding'),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HeaderWaveClipper(),
      child: Container(
        height: 285,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [HomeScreen._primaryDark, HomeScreen._primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -90,
              top: 38,
              child: _GlowCircle(size: 260, opacity: 0.12),
            ),
            Positioned(
              left: -70,
              top: -52,
              child: _GlowCircle(size: 220, opacity: 0.10),
            ),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 430;
                  final actionSize = compact ? 44.0 : 52.0;
                  final logoSize = compact ? 54.0 : 66.0;
                  final horizontalPadding = compact ? 18.0 : 22.0;
                  final titleStyle =
                      (compact
                              ? Theme.of(context).textTheme.titleLarge
                              : Theme.of(context).textTheme.headlineSmall)
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          );

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      18,
                      horizontalPadding,
                      0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _AppLogo(size: logoSize),
                        SizedBox(width: compact ? 12 : 16),
                        Expanded(
                          child: Text(
                            'Sistema Integrado\nSindicato',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        _HeaderActionButton(
                          icon: Icons.notifications_rounded,
                          tooltip: 'Notificaciones',
                          size: actionSize,
                          onTap: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No hay notificaciones pendientes',
                                  ),
                                ),
                              ),
                        ),
                        SizedBox(width: compact ? 6 : 10),
                        _HeaderActionButton(
                          icon: Icons.person_rounded,
                          tooltip: 'Mi perfil',
                          light: true,
                          size: actionSize,
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                        ),
                        SizedBox(width: compact ? 6 : 10),
                        _HeaderActionButton(
                          icon: Icons.logout_rounded,
                          tooltip: 'Cerrar sesión',
                          size: actionSize,
                          onTap: () async {
                            await context.read<AuthProvider>().signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/login',
                                (route) => false,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.diversity_3_rounded,
            color: HomeScreen._primary.withValues(alpha: 0.88),
            size: size * 0.60,
          ),
          Positioned(
            bottom: size * 0.15,
            child: Container(
              width: size * 0.45,
              height: size * 0.12,
              decoration: BoxDecoration(
                color: HomeScreen._primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.light = false,
    this.size = 52,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: light ? Colors.white : Colors.white.withValues(alpha: 0.13),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: light ? HomeScreen._primaryDark : Colors.white,
              size: size * 0.54,
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.user,
    required this.userName,
    required this.roleName,
  });

  final AppUser? user;
  final String userName;
  final String roleName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E0FA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A271B5E),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          return Padding(
            padding: EdgeInsets.fromLTRB(22, 22, compact ? 18 : 10, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '¡Bienvenido!',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: HomeScreen._primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: HomeScreen._primary,
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          userName,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: HomeScreen._ink,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                        ),
                        const SizedBox(height: 18),
                        RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: HomeScreen._muted,
                                  height: 1.2,
                                ),
                            children: [
                              const TextSpan(
                                text: 'Rol:  ',
                                style: TextStyle(
                                  color: HomeScreen._primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(text: roleName),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!compact)
                  SizedBox(
                    width: 210,
                    height: 190,
                    child: _WelcomeAvatarBlock(user: user),
                  )
                else
                  SizedBox(
                    width: 118,
                    height: 154,
                    child: _WelcomeAvatarBlock(user: user, compact: true),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeAvatarBlock extends StatelessWidget {
  const _WelcomeAvatarBlock({required this.user, this.compact = false});

  final AppUser? user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 92.0 : 148.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          right: compact ? 0 : 18,
          top: compact ? 22 : 18,
          child: Container(
            width: compact ? 105 : 162,
            height: compact ? 105 : 162,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFE9DDFC), Color(0xFFF7F1FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          right: compact ? 10 : 24,
          bottom: compact ? 4 : 6,
          child: SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: Consumer<AuthProvider>(
              builder: (_, auth, __) {
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    DashboardWelcomeAvatar(user: user, size: avatarSize),
                    if (auth.isLoading)
                      Positioned.fill(
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: compact ? 28 : 36,
                            height: compact ? 28 : 36,
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        Positioned(
          right: compact ? 2 : 8,
          top: compact ? 18 : 14,
          child: Material(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black26,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: user == null ? null : () => _showDashboardAvatarSheet(context),
              child: Padding(
                padding: EdgeInsets.all(compact ? 5 : 7),
                child: Icon(
                  Icons.edit_rounded,
                  size: compact ? 16 : 20,
                  color: HomeScreen._primary,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: compact ? 8 : 20,
          top: compact ? 50 : 68,
          child: _Dot(size: compact ? 11 : 16),
        ),
        Positioned(
          right: compact ? 2 : 2,
          bottom: compact ? 44 : 62,
          child: _Dot(size: compact ? 9 : 13),
        ),
      ],
    );
  }
}

Future<void> _showDashboardAvatarSheet(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.man_2_outlined),
              title: const Text('Avatar masculino (por defecto)'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await auth.saveDefaultAvatar(UserAvatarMode.defaultMale);
                if (context.mounted && auth.errorMessage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preferencia de avatar guardada')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.woman_2_outlined),
              title: const Text('Avatar femenino (por defecto)'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await auth.saveDefaultAvatar(UserAvatarMode.defaultFemale);
                if (context.mounted && auth.errorMessage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preferencia de avatar guardada')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Avatar neutro (por defecto)'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await auth.saveDefaultAvatar(UserAvatarMode.defaultNeutral);
                if (context.mounted && auth.errorMessage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preferencia de avatar guardada')),
                  );
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Subir imagen desde galería'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await auth.pickAndUploadCustomAvatar();
                if (context.mounted && auth.errorMessage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Avatar actualizado')),
                  );
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.modules});

  final List<_HomeModule> modules;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 340 ? 1 : 2;
        final spacing = columns == 1 ? 14.0 : 18.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 18,
          children: modules
              .map(
                (module) => SizedBox(
                  width: width,
                  child: _ModuleCard(module: module),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module});

  final _HomeModule module;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 180;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          elevation: 0,
          child: InkWell(
            onTap: module.onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              constraints: BoxConstraints(minHeight: narrow ? 224 : 206),
              padding: EdgeInsets.all(narrow ? 15 : 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE9E3F4)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14271B5E),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: narrow ? 32 : 34,
                      height: narrow ? 32 : 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E6FF),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: HomeScreen._primary,
                        size: narrow ? 22 : 24,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModuleIcon(icon: module.icon, size: narrow ? 62 : 70),
                      SizedBox(height: narrow ? 30 : 34),
                      Text(
                        module.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HomeScreen._ink,
                          fontSize: narrow ? 19 : 20,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        module.subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HomeScreen._muted,
                          fontSize: narrow ? 15 : 16,
                          height: 1.16,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _MiniProgress(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModuleIcon extends StatelessWidget {
  const _ModuleIcon({required this.icon, this.size = 70});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFF0E6FF), Color(0xFFF8F2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, size: size * 0.63, color: HomeScreen._primary),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 4,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: HomeScreen._primary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE4DEF0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4DBF2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_rounded,
            size: 40,
            color: HomeScreen._primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistema seguro',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: HomeScreen._primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tu actividad está protegida y registrada.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: HomeScreen._muted),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.shield_outlined,
            size: 42,
            color: HomeScreen._primary,
          ),
        ],
      ),
    );
  }
}

class _BottomHomeNavigation extends StatelessWidget {
  const _BottomHomeNavigation({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin || role == UserRole.superadmin;
    final canManageAttendance = isAdmin || role == UserRole.operadorAsistencia;
    final entries = [
      const _BottomNavEntry(
        label: 'Inicio',
        icon: Icons.home_outlined,
        selected: true,
      ),
      const _BottomNavEntry(
        label: 'Voto',
        icon: Icons.how_to_vote_outlined,
        route: '/voto/elections',
      ),
      if (canManageAttendance)
        const _BottomNavEntry(
          label: 'Asist.',
          icon: Icons.check_rounded,
          route: '/asistencia',
        ),
      if (isAdmin)
        const _BottomNavEntry(
          label: 'Socios',
          icon: Icons.groups_rounded,
          route: '/members',
        ),
      const _BottomNavEntry(
        label: 'Perfil',
        icon: Icons.person_outline_rounded,
        route: '/profile',
      ),
    ];

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
          children: entries
              .map((entry) => _BottomNavItem(entry: entry))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({required this.entry});

  final _BottomNavEntry entry;

  @override
  Widget build(BuildContext context) {
    final selected = entry.selected;
    final foreground = selected ? HomeScreen._primary : HomeScreen._muted;

    return Expanded(
      child: Tooltip(
        message: entry.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: selected || entry.route == null
                ? null
                : () => Navigator.pushNamed(context, entry.route!),
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
                        color: const Color(0xFFEBDDFF),
                        borderRadius: BorderRadius.circular(22),
                      )
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(entry.icon, color: foreground, size: 18),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        entry.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HomeScreen._primary.withValues(alpha: 0.18),
      ),
    );
  }
}

class _HeaderWaveClipper extends CustomClipper<Path> {
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

class _HomeModule {
  const _HomeModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _BottomNavEntry {
  const _BottomNavEntry({
    required this.label,
    required this.icon,
    this.route,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final String? route;
  final bool selected;
}
